param([string]$RequestPath,[string]$ResponsePath,[string]$WaitResponsePath,[int]$WaitSeconds=15,[string]$DispatchUI,[string]$DispatchResponsePath,[string]$ScriptsRoot)
if ($WaitResponsePath) {
    [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
    $deadline = [DateTime]::UtcNow.AddSeconds([Math]::Min(20,[Math]::Max(1,$WaitSeconds)))
    while ([DateTime]::UtcNow -lt $deadline) {
        if ([IO.File]::Exists($WaitResponsePath)) {
            $body=[IO.File]::ReadAllText($WaitResponsePath,[Text.Encoding]::UTF8)
            if ($body) { [Console]::WriteLine($body); exit 0 }
        }
        Start-Sleep -Milliseconds 50
    }
    [Console]::WriteLine('{"pending":true}')
    exit 0
}
$ErrorActionPreference = 'Stop'
[Console]::OutputEncoding = New-Object System.Text.UTF8Encoding($false)
try {
    Add-Type -AssemblyName System.Windows.Forms,System.Drawing,System.Web.Extensions,UIAutomationClient,UIAutomationTypes
    Add-Type -ReferencedAssemblies System.Windows.Forms,System.Drawing,System.Web.Extensions,UIAutomationClient,UIAutomationTypes -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Linq;
using System.Windows.Forms;
using System.Windows.Automation;
using System.Web.Script.Serialization;
using System.Diagnostics;
using System.IO;
using System.Threading;
public class WheelItem { public int slot; public string name; public string mode; public bool available; }
public class WheelProfile { public string name; public WheelItem[] items; }
public class WheelRequest { public int version; public int active; public bool reducedMotion; public double timeoutSeconds; public WheelProfile[] profiles; public string accent; public string accentText; }
public class CavalryWheelForm : Form {
    WheelRequest request; int active, selected=-1, pressed=-1; float scroll;
    const float cx=220, cy=249, outer=194, inner=90, radialMotion=6;
    public string Response="{\"version\":1,\"action\":\"cancel\"}";
    public string ResponsePath;
    public bool ResponseWritten { get; private set; }
    bool complete, hasMousePress;
    float[] hover=new float[0], hoverFrom=new float[0], press=new float[0], pressFrom=new float[0], closeValues=new float[0];
    DateTime hoverStart=DateTime.MinValue, pressStart=DateTime.MinValue, closeStart=DateTime.MinValue;
    readonly System.Windows.Forms.Timer motionTimer=new System.Windows.Forms.Timer(), closeTimer=new System.Windows.Forms.Timer();
    readonly System.Diagnostics.Stopwatch pointerClock=System.Diagnostics.Stopwatch.StartNew();
    WheelItem[] Items { get { return request.profiles[active].items; } }
    static Color Ink=Color.FromArgb(240,242,243), Muted=Color.FromArgb(170,179,191), Bright=Color.FromArgb(47,205,113);
    Color ThemeColor(string value,Color fallback) { try { return ColorTranslator.FromHtml(value); } catch { return fallback; } }
    Color Accent { get { return ThemeColor(request.accent,Color.FromArgb(7,132,48)); } }
    Color AccentText { get { return ThemeColor(request.accentText,Bright); } }
    public CavalryWheelForm(string json) {
        request=new JavaScriptSerializer().Deserialize<WheelRequest>(json);
        if(request==null || request.version!=1 || request.profiles==null || request.profiles.Length<1 || request.profiles.Length>20) throw new Exception("Invalid wheel request");
        foreach(var p in request.profiles) {
            if(p.items==null || p.items.Length>12) throw new Exception("Invalid profile");
            foreach(var i in p.items) if(i.slot<0 || i.slot>11 || (i.mode!="script" && i.mode!="ui")) throw new Exception("Invalid slot");
        }
        active=Math.Min(Math.Max(request.active,0),request.profiles.Length-1);
        motionTimer.Interval=16;motionTimer.Tick+=(s,e)=>AdvanceMotion();
        closeTimer.Interval=16;closeTimer.Tick+=(s,e)=>AdvanceClose();
        ResetInteraction();
        Text="Cavalry Wheel"; FormBorderStyle=FormBorderStyle.None; ShowInTaskbar=false; TopMost=true;
        BackColor=Color.Magenta; TransparencyKey=Color.Magenta; DoubleBuffered=true; KeyPreview=true;
        ClientSize=new Size(440,496); StartPosition=FormStartPosition.Manual;
        var at=Cursor.Position; var area=Screen.FromPoint(at).WorkingArea;
        Location=new Point(Math.Max(area.Left,Math.Min(at.X-(int)cx,area.Right-Width)),Math.Max(area.Top,Math.Min(at.Y-(int)cy,area.Bottom-Height)));
        AccessibleName="Cavalry 脚本轮盘";
        MouseMove+=(s,e)=>Pick(Hit(e.Location));
        MouseLeave+=(s,e)=>{Pick(-1);Press(-1);};
        MouseDown+=(s,e)=>{
            if(e.Button!=MouseButtons.Left || pointerClock.ElapsedMilliseconds<150)return;
            hasMousePress=true;var hit=Hit(e.Location);Pick(hit);Press(hit);
        };
        MouseUp+=(s,e)=>{
            if(e.Button==MouseButtons.Right){Finish("{\"version\":1,\"action\":\"cancel\"}",true);return;}
            if(e.Button!=MouseButtons.Left || !hasMousePress || pointerClock.ElapsedMilliseconds<150)return;
            hasMousePress=false;Press(-1);
            if(e.Y>454){Finish("{\"version\":1,\"action\":\"settings\"}",true);return;}
            var hit=Hit(e.Location);if(hit<0){Finish("{\"version\":1,\"action\":\"cancel\"}",true);return;}
            Pick(hit);RunSelection(true);
        };
        MouseWheel+=(s,e)=>{scroll+=e.Delta/120f;if(Math.Abs(scroll)>=1){Step(scroll<0?1:-1);scroll=0;}};
        KeyDown+=(s,e)=>{
            if(e.KeyCode==Keys.Escape){Close();e.Handled=true;}
            else if(e.KeyCode==Keys.Return){RunSelection();e.Handled=true;}
            else if(e.KeyCode==Keys.Left || e.KeyCode==Keys.Up){Step(-1);e.Handled=true;}
            else if(e.KeyCode==Keys.Right || e.KeyCode==Keys.Down){Step(1);e.Handled=true;}
            else if(e.KeyCode==Keys.Oem3){active=(active+(e.Shift?request.profiles.Length-1:1))%request.profiles.Length;selected=-1;pressed=-1;ResetInteraction();Invalidate();e.Handled=true;}
        };
        Deactivate+=(s,e)=>Close();
        var expiry=new System.Windows.Forms.Timer();expiry.Interval=(int)(Math.Min(180,Math.Max(15,request.timeoutSeconds<=0?180:request.timeoutSeconds))*1000);
        expiry.Tick+=(s,e)=>{expiry.Stop();Close();};Shown+=(s,e)=>expiry.Start();FormClosed+=(s,e)=>{expiry.Dispose();motionTimer.Dispose();closeTimer.Dispose();};
    }
    void ResetInteraction(){
        motionTimer.Stop();closeTimer.Stop();
        int n=Items.Length;hover=new float[n];hoverFrom=new float[n];press=new float[n];pressFrom=new float[n];
        closeValues=Enumerable.Repeat(1f,n).ToArray();
    }
    static float Clamp(float value){return Math.Max(0,Math.Min(1,value));}
    static float EaseOut(float progress){
        if(progress<=0 || progress>=1)return progress;
        float low=0,high=1,t=0;
        for(int i=0;i<14;i++){
            t=(low+high)/2;float u=1-t;
            float x=3*u*u*t*.23f+3*u*t*t*.32f+t*t*t;
            if(x<progress)low=t;else high=t;
        }
        return 1-(float)Math.Pow(1-t,3);
    }
    void SnapInteraction(){
        motionTimer.Stop();
        for(int i=0;i<Items.Length;i++){hover[i]=i==selected?1:0;press[i]=i==pressed?1:0;}
        Invalidate();
    }
    void Pick(int index,bool animated=true){
        if(complete || index==selected)return;
        if(motionTimer.Enabled)AdvanceMotion();
        selected=index;AccessibleDescription=selected>=0?Items[selected].name:request.profiles[active].name;
        if(request.reducedMotion || !animated){SnapInteraction();return;}
        hoverFrom=(float[])hover.Clone();hoverStart=DateTime.UtcNow;motionTimer.Start();Invalidate();
    }
    void Press(int index){
        if(complete || index==pressed)return;
        if(motionTimer.Enabled)AdvanceMotion();
        pressed=index;
        if(request.reducedMotion){SnapInteraction();return;}
        pressFrom=(float[])press.Clone();pressStart=DateTime.UtcNow;motionTimer.Start();Invalidate();
    }
    void AdvanceMotion(){
        float ht=Clamp((float)(DateTime.UtcNow-hoverStart).TotalMilliseconds/160),pt=Clamp((float)(DateTime.UtcNow-pressStart).TotalMilliseconds/120);
        float he=EaseOut(ht),pe=EaseOut(pt);
        for(int i=0;i<Items.Length;i++){
            hover[i]=hoverFrom[i]+((i==selected?1:0)-hoverFrom[i])*he;
            press[i]=pressFrom[i]+((i==pressed?1:0)-pressFrom[i])*pe;
        }
        if(ht>=1 && pt>=1)SnapInteraction();else Invalidate();
    }
    int Hit(Point point){float dx=point.X-cx,dy=point.Y-cy;var r=Math.Sqrt(dx*dx+dy*dy);if(r<inner||r>outer+7||Items.Length==0)return -1;var angle=(Math.Atan2(dy,dx)+Math.PI/2+Math.PI*2)%(Math.PI*2);return Math.Min(Items.Length-1,(int)(angle/(Math.PI*2/Items.Length)));}
    void Step(int delta){if(Items.Length==0)return;pressed=-1;Pick(selected<0?(delta>0?0:Items.Length-1):(selected+delta+Items.Length)%Items.Length,false);}
    void RunSelection(bool animated=false){if(selected<0 || !Items[selected].available){System.Media.SystemSounds.Beep.Play();return;}Finish("{\"version\":1,\"action\":\"run\",\"profile\":"+active+",\"slot\":"+Items[selected].slot+"}",animated);}
    void WriteResponse(){
        if(ResponseWritten)return;ResponseWritten=true;
        if(!string.IsNullOrEmpty(ResponsePath)){
            string temp=ResponsePath+".writing";File.WriteAllText(temp,Response,new System.Text.UTF8Encoding(false));File.Move(temp,ResponsePath);
        }else Console.WriteLine(Response);
    }
    void Finish(string response,bool animated=false){
        if(complete)return;complete=true;Response=response;WriteResponse();
        if(animated && !request.reducedMotion && Items.Length>0){closeStart=DateTime.UtcNow;closeTimer.Start();Invalidate();}
        else Close();
    }
    void AdvanceClose(){
        bool done=true;
        for(int i=0;i<Items.Length;i++){
            float t=Clamp((float)(DateTime.UtcNow-closeStart).TotalMilliseconds/160-i*.01f);
            closeValues[i]=1-EaseOut(t);done &= t>=1;
        }
        if(done){for(int i=0;i<Items.Length;i++)closeValues[i]=0;closeTimer.Stop();Close();}
        else Invalidate();
    }
    static Color Blend(Color from,Color to,float amount){
        float t=Clamp(amount);
        return Color.FromArgb((int)(from.A+(to.A-from.A)*t),(int)(from.R+(to.R-from.R)*t),(int)(from.G+(to.G-from.G)*t),(int)(from.B+(to.B-from.B)*t));
    }
    static Color Alpha(Color value,float amount){return Color.FromArgb((int)(value.A*Clamp(amount)),value.R,value.G,value.B);}
public class UIDispatchRequest { public int version; public int hostPID; public string target; }
public class UIDispatchResult {
    public string action="ui-dispatch",status="error",message="UI 分派未完成。",target="";
    public UIDispatchResult() {}
    public UIDispatchResult(string status,string message,string target){this.status=status;this.message=message;this.target=target;}
}
public static class CavalryUIDispatcher {
    static bool IsCavalry(int pid){
        try { using(var process=Process.GetProcessById(pid)) return !process.HasExited && string.Equals(process.ProcessName,"Cavalry",StringComparison.OrdinalIgnoreCase); }
        catch { return false; }
    }
    static AutomationElement[] Find(AutomationElement root,string name,ControlType type){
        if(root==null)return new AutomationElement[0];
        var matches=root.FindAll(TreeScope.Descendants,new PropertyCondition(AutomationElement.ControlTypeProperty,type));
        return matches.Cast<AutomationElement>().Where(e=>e.Current.Name==name).ToArray();
    }
    static void Invoke(AutomationElement element){
        object pattern;
        if(element.TryGetCurrentPattern(InvokePattern.Pattern,out pattern)){((InvokePattern)pattern).Invoke();return;}
        if(element.TryGetCurrentPattern(ExpandCollapsePattern.Pattern,out pattern)){((ExpandCollapsePattern)pattern).Expand();return;}
        if(element.TryGetCurrentPattern(SelectionItemPattern.Pattern,out pattern)){((SelectionItemPattern)pattern).Select();return;}
        throw new Exception("菜单项不支持调用或展开。");
    }
    static string[] Components(string target,string root){
        string file=Path.GetFullPath(target),directory=Path.GetFullPath(root).TrimEnd(Path.DirectorySeparatorChar)+Path.DirectorySeparatorChar;
        if(!file.StartsWith(directory,StringComparison.OrdinalIgnoreCase))return null;
        var parts=file.Substring(directory.Length).Split(new[]{'/','\\'},StringSplitOptions.RemoveEmptyEntries);
        if(parts.Length==0 || parts.Length>24 || parts.Take(parts.Length-1).Any(x=>x.EndsWith("_assets") || x.StartsWith(".")))return null;
        parts[parts.Length-1]=Path.GetFileNameWithoutExtension(parts[parts.Length-1]);return parts;
    }
    public static UIDispatchResult Run(UIDispatchRequest request,string scriptsRoot,string template){
        string relay=null,relayBytes=null,receipt=null;
        try {
            if(request==null || request.version!=1 || request.hostPID<=0 || string.IsNullOrEmpty(request.target) || !Path.IsPathRooted(request.target))return new UIDispatchResult("error","UI 分派请求无效。",request==null?"":request.target);
            if(!IsCavalry(request.hostPID))return new UIDispatchResult("error","发起调用的 Cavalry 实例已不可用；未选择其他实例代替。",request.target);
            string ext=Path.GetExtension(request.target).ToLowerInvariant();
            if(!File.Exists(request.target) || (ext!=".js" && ext!=".jsc"))return new UIDispatchResult("error","所选 UI 脚本已不存在或类型不支持。",request.target);
            var components=Components(request.target,scriptsRoot);
            if(components==null){
                if(ext!=".js")return new UIDispatchResult("unsupported-external-jsc","外部加密 UI 脚本不能通过源码中继执行；请将原 .jsc 及资源安装到 Cavalry Scripts，再重新绑定。",request.target);
                string id=Guid.NewGuid().ToString("N");relay=Path.Combine(scriptsRoot,"CavalryToolbar_UIDispatch_"+id+".js");receipt=Path.Combine(Path.GetTempPath(),"CavalryWheel-UIReceipt-"+id+".json");
                string payload=new JavaScriptSerializer().Serialize(new {target=request.target,directory=Path.GetDirectoryName(request.target),receipt=receipt});
                if(template.Split(new[]{"__CAVALRY_WHEEL_DISPATCH__"},StringSplitOptions.None).Length!=2)throw new Exception("UI 中继模板无效。");
                relayBytes=template.Replace("__CAVALRY_WHEEL_DISPATCH__",payload);File.WriteAllText(relay,relayBytes,new System.Text.UTF8Encoding(false));
                components=new[]{Path.GetFileNameWithoutExtension(relay)};
            }
            var root=AutomationElement.RootElement.FindFirst(TreeScope.Children,new PropertyCondition(AutomationElement.ProcessIdProperty,request.hostPID));
            if(root==null)return new UIDispatchResult("error","Cavalry 主窗口不可用。",request.target);
            var scripts=Find(root,"Scripts",ControlType.MenuItem).Concat(Find(root,"脚本",ControlType.MenuItem)).ToArray();
            if(scripts.Length!=1)return new UIDispatchResult("error","没有找到唯一的 Scripts 菜单。",request.target);
            Invoke(scripts[0]);Thread.Sleep(80);
            foreach(var component in components){
                var matches=Find(root,component,ControlType.MenuItem);
                if(matches.Length!=1)return new UIDispatchResult("error","没有找到唯一的脚本菜单项："+component,request.target);
                Invoke(matches[0]);Thread.Sleep(50);
            }
            if(receipt!=null){
                var deadline=DateTime.UtcNow.AddSeconds(12);
                while(!File.Exists(receipt) && DateTime.UtcNow<deadline)Thread.Sleep(50);
                if(!File.Exists(receipt))return new UIDispatchResult("completion-unknown","菜单已调用，但未收到 UI 求值回执；未重试脚本。",request.target);
                var result=new JavaScriptSerializer().Deserialize<dynamic>(File.ReadAllText(receipt));
                if(result["status"]!="evaluated")return new UIDispatchResult("script-error","UI 脚本报告错误，可能已经部分运行。",request.target);
                return new UIDispatchResult("evaluated","外部 UI 源码已在 Cavalry UI 引擎求值；请检查实际面板结果。",request.target);
            }
            return new UIDispatchResult("menu-invoked","已调用原 Cavalry 实例的脚本菜单；请检查实际面板结果。",request.target);
        } catch(Exception error) { return new UIDispatchResult("error",error.Message,request==null?"":request.target); }
        finally {
            if(relay!=null && relayBytes!=null && File.Exists(relay) && File.ReadAllText(relay)==relayBytes)File.Delete(relay);
            if(receipt!=null && File.Exists(receipt))File.Delete(receipt);
        }
    }
}
struct ArcTextLayout { public float middle,angleStep,metaRadius,maxNameWidth,metaSize,nameSize; public float[] nameRadii; }
    ArcTextLayout ArcLayout(int index,int count) {
        int n=Math.Max(1,count); float step=(float)(Math.PI*2/n),middle=(float)(-Math.PI/2+step*(index+.5));
        return new ArcTextLayout {
            middle=middle,angleStep=step,metaRadius=n>=10?inner+12:inner+20,
            nameRadii=n>=10?new float[]{outer-76,outer-62,outer-48,outer-34}:new float[]{outer-66,outer-46,outer-27},
            maxNameWidth=(outer-27)*(float)Math.Max(.1,step-.06),metaSize=n>=10?9:10,nameSize=n>=10?9:n>=5?11:12
        };
    }
    string[] NameLines(Graphics g,string text,Font font,float maxWidth,int maxLines) {
        var chars=text.ToCharArray(); var lines=new System.Collections.Generic.List<string>();
        int start=0;
        while(start<chars.Length && lines.Count<maxLines) {
            int end=start,lastBreak=-1; bool overflow=false;
            while(end<chars.Length) {
                string candidate=new string(chars,start,end-start+1);
                if(g.MeasureString(candidate,font).Width>maxWidth && end>start) {
                    int split=lastBreak>start?lastBreak:end;
                    lines.Add(new string(chars,start,split-start));start=split;overflow=true;break;
                }
                end++;
                if(end>start && (chars[end-1]=='-' || chars[end-1]=='_' || chars[end-1]==' '))lastBreak=end;
            }
            if(!overflow) {
                if(end>start){lines.Add(new string(chars,start,end-start));start=end;}
                else {lines.Add(chars[start].ToString());start++;}
            }
        }
        if(start<chars.Length && lines.Count>0) {
            string last=lines[lines.Count-1];lines.RemoveAt(lines.Count-1);
            while(last.Length>0 && g.MeasureString(last+"…",font).Width>maxWidth)last=last.Substring(0,last.Length-1);
            lines.Add(last+"…");
        }
        return lines.ToArray();
    }
    void ArcText(Graphics g,string text,float size,FontStyle weight,Color tint,float x,float y,float radius,float middle,float maxWidth) {
        if(text.Length==0 || radius<=0 || maxWidth<=0)return;
        using(var font=new Font("Microsoft YaHei UI",size,weight,GraphicsUnit.Pixel)) {
            var chars=text.ToCharArray();var widths=chars.Select(c=>g.MeasureString(c.ToString(),font).Width).ToArray();
            float raw=widths.Sum(),fit=Math.Min(1,maxWidth/Math.Max(raw,.001f)),total=raw*fit;
            float direction=(float)(Math.Sin(middle)<=0?1:-1),start=direction>0?middle-total/(2*radius):middle+total/(2*radius),travelled=0;
            for(int i=0;i<chars.Length;i++) {
                float width=widths[i]*fit,theta=start+direction*(travelled+width/2)/radius;
                float px=x+(float)Math.Cos(theta)*radius,py=y+(float)Math.Sin(theta)*radius;
                float rotation=(direction>0?theta+(float)Math.PI/2:theta-(float)Math.PI/2)*180/(float)Math.PI;
                var state=g.Save();g.TranslateTransform(px,py);g.RotateTransform(rotation);if(fit<1)g.ScaleTransform(fit,fit);
                LabelText(g,chars[i].ToString(),size,weight,tint,new RectangleF(-widths[i]/2,-size*.65f,Math.Max(1,widths[i]),size*1.3f));
                g.Restore(state);travelled+=width;
            }
        }
    }
    void LabelText(Graphics g,string value,float size,FontStyle weight,Color tint,RectangleF rect){
        using(var font=new Font("Microsoft YaHei UI",size,weight,GraphicsUnit.Pixel))
        using(var brush=new SolidBrush(tint))
        using(var format=new StringFormat{Alignment=StringAlignment.Center,LineAlignment=StringAlignment.Center,Trimming=StringTrimming.EllipsisCharacter})g.DrawString(value,font,brush,rect,format);
    }
        protected override void OnPaint(PaintEventArgs e){
        var g=e.Graphics;g.SmoothingMode=SmoothingMode.AntiAlias;g.TextRenderingHint=System.Drawing.Text.TextRenderingHint.ClearTypeGridFit;
        int count=Math.Max(Items.Length,1);float step=360f/count;
        for(int n=0;n<count;n++){
            float middle=(float)((-90+step*(n+.5))*Math.PI/180),amount=n<hover.Length?hover[n]:0,pressure=n<press.Length?press[n]:0,open=n<closeValues.Length?closeValues[n]:1;
            if(open<=.001f)continue;
            float lift=request.reducedMotion?0:radialMotion*(amount-pressure);
            float x=cx+(float)Math.Cos(middle)*lift,y=cy+(float)Math.Sin(middle)*lift,start=-90+step*n+.6f,sweep=step-1.2f;
            float scale=.55f+.45f*open,rotation=(1-Math.Min(open,1))*-.35f*180/(float)Math.PI;
            var state=g.Save();g.TranslateTransform(x,y);g.RotateTransform(rotation);g.ScaleTransform(scale,scale);g.TranslateTransform(-cx,-cy);
            using(var path=new GraphicsPath()){
                path.AddArc(cx-outer,cy-outer,outer*2,outer*2,start,sweep);
                path.AddArc(cx-inner,cy-inner,inner*2,inner*2,start+sweep,-sweep);path.CloseFigure();
                bool available=n<Items.Length && Items[n].available;
                var rest=Color.FromArgb(38,43,52),hoverFill=available?Accent:Color.FromArgb(24,48,34);
                var fill=Blend(Blend(rest,hoverFill,amount),Color.FromArgb(21,24,30),pressure*.25f);
                using(var brush=new SolidBrush(Alpha(fill,open)))g.FillPath(brush,path);
                using(var pen=new Pen(Alpha(Blend(Color.FromArgb(59,66,77),AccentText,amount),open),1))g.DrawPath(pen,path);
            }
            if(n<Items.Length){
                var layout=ArcLayout(n,count);
                ArcText(g,(Items[n].slot+1).ToString("00")+" · "+Items[n].mode.ToUpperInvariant(),layout.metaSize,FontStyle.Regular,Alpha(Blend(Muted,Color.White,amount),open),cx,cy,layout.metaRadius,layout.middle,layout.metaRadius*(float)Math.Max(.1,layout.angleStep-.06));
                using(var font=new Font("Microsoft YaHei UI",layout.nameSize,FontStyle.Bold,GraphicsUnit.Pixel)) {
                    var lines=NameLines(g,Items[n].name,font,layout.maxNameWidth,count>=10?4:2);
                    var radii=lines.Length==1?new float[]{outer-32}:layout.nameRadii.Skip(layout.nameRadii.Length-lines.Length).ToArray();
                    for(int line=0;line<lines.Length;line++)
                        ArcText(g,lines[line],layout.nameSize,FontStyle.Bold,Alpha(Items[n].available?Ink:Color.Goldenrod,open),cx,cy,radii[line],layout.middle,radii[line]*(float)Math.Max(.1,layout.angleStep-.06));
                }
            }
            g.Restore(state);
        }
        using(var b=new SolidBrush(Color.FromArgb(29,33,41)))g.FillEllipse(b,cx-inner+5,cy-inner+5,(inner-5)*2,(inner-5)*2);
        LabelText(g,selected>=0?(Items[selected].slot+1).ToString("00"):request.profiles[active].name,selected>=0?20:15,FontStyle.Bold,Ink,new RectangleF(cx-70,cy-40,140,48));
        LabelText(g,selected>=0?"点击 / 回车运行":Items.Length==0?"先在配置页添加脚本":Items.Length+" 个脚本",11,FontStyle.Regular,AccentText,new RectangleF(cx-75,cy+8,150,20));
        LabelText(g,"中心 / Esc 取消",10,FontStyle.Regular,Muted,new RectangleF(cx-70,cy+30,140,18));
        using(var b=new SolidBrush(Color.FromArgb(21,24,30)))g.FillRectangle(b,75,454,290,42);
        LabelText(g,"滚轮 / 方向键选择 · ` 切换配置",11,FontStyle.Regular,Muted,new RectangleF(75,457,290,18));
        LabelText(g,"打开配置",10,FontStyle.Regular,AccentText,new RectangleF(75,477,290,16));
    }
}
'@
    if ($DispatchUI) {
        try {
            $dispatchRequest = [IO.File]::ReadAllText($DispatchUI,[Text.Encoding]::UTF8) | ConvertFrom-Json
            $request = New-Object UIDispatchRequest
            $request.version = [int]$dispatchRequest.version
            $request.hostPID = [int]$dispatchRequest.hostPID
            $request.target = [string]$dispatchRequest.target
            if (-not $ScriptsRoot) { $ScriptsRoot = Split-Path -Parent $PSScriptRoot }
            $template = [IO.File]::ReadAllText((Join-Path $PSScriptRoot 'UIRelay.js'),[Text.Encoding]::UTF8)
            $result = [CavalryUIDispatcher]::Run($request,$ScriptsRoot,$template)
        } catch {
            $result = New-Object UIDispatchResult('error',$_.Exception.Message,$DispatchUI)
        }
        $message=$result | ConvertTo-Json -Compress
        if ($DispatchResponsePath) {
            $temp=$DispatchResponsePath+'.writing'
            [IO.File]::WriteAllText($temp,$message,(New-Object Text.UTF8Encoding($false)))
            [IO.File]::Move($temp,$DispatchResponsePath)
        } else { [Console]::WriteLine($message) }
        exit 0
    }
    $json = [IO.File]::ReadAllText($RequestPath,[Text.Encoding]::UTF8)
    if ($json.Length -gt 262144) { throw 'Request too large' }
    [Windows.Forms.Application]::EnableVisualStyles()
    $form = New-Object CavalryWheelForm($json)
    $form.ResponsePath = $ResponsePath
    [Windows.Forms.Application]::Run($form)
    if (-not $form.ResponseWritten) {
        if ($ResponsePath) {
            $temp=$ResponsePath+'.writing'
            [IO.File]::WriteAllText($temp,$form.Response,(New-Object Text.UTF8Encoding($false)))
            [IO.File]::Move($temp,$ResponsePath)
        } else { [Console]::WriteLine($form.Response) }
    }
} catch {
    $message=(@{version=1;action='error';message=$_.Exception.Message} | ConvertTo-Json -Compress)
    if ($DispatchResponsePath) { [IO.File]::WriteAllText($DispatchResponsePath,$message,(New-Object Text.UTF8Encoding($false))) }
    elseif ($ResponsePath) { [IO.File]::WriteAllText($ResponsePath,$message,(New-Object Text.UTF8Encoding($false))) }
    else { [Console]::WriteLine($message) }
    exit 1
}
