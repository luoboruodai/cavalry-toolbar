param([string]$RequestPath,[string]$ResponsePath,[string]$WaitResponsePath,[int]$WaitSeconds=15)
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
    $winFormsReferences = @('System.Windows.Forms', 'System.Drawing', 'System.Web.Extensions')
    if ($PSVersionTable.PSEdition -eq 'Core') {
        $winFormsReferences += @('System.Core', 'System.Linq', 'System.ComponentModel.Primitives', 'System.Drawing.Primitives', 'System.Windows.Forms.Primitives', 'System.Drawing.Common', 'mscorlib', 'System.Runtime', 'netstandard')
    }
    Add-Type -AssemblyName $winFormsReferences
    Add-Type -ReferencedAssemblies $winFormsReferences -TypeDefinition @'
using System;
using System.Drawing;
using System.Drawing.Drawing2D;
using System.Linq;
using System.Windows.Forms;
using System.Web.Script.Serialization;
public class WheelItem { public int slot; public string name; public string mode; public bool available; }
public class WheelProfile { public string name; public WheelItem[] items; }
public class WheelRequest { public int version; public int active; public bool reducedMotion; public double timeoutSeconds; public WheelProfile[] profiles; public string accent; public string accentText; }
public class CavalryWheelForm : Form {
    WheelRequest request; int active, selected=-1; float scroll;
    const float cx=220, cy=249, outer=194, inner=90;
    public string Response="{\"version\":1,\"action\":\"cancel\"}";
    bool complete, hasMousePress;
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
        Text="Cavalry Wheel"; FormBorderStyle=FormBorderStyle.None; ShowInTaskbar=false; TopMost=true;
        BackColor=Color.Magenta; TransparencyKey=Color.Magenta; DoubleBuffered=true; KeyPreview=true;
        ClientSize=new Size(440,496); StartPosition=FormStartPosition.Manual;
        var at=Cursor.Position; var area=Screen.FromPoint(at).WorkingArea;
        Location=new Point(Math.Max(area.Left,Math.Min(at.X-(int)cx,area.Right-Width)),Math.Max(area.Top,Math.Min(at.Y-(int)cy,area.Bottom-Height)));
        AccessibleName="Cavalry 脚本轮盘";
        MouseMove+=(s,e)=>Pick(Hit(e.Location));
        MouseDown+=(s,e)=>{if(e.Button==MouseButtons.Left && pointerClock.ElapsedMilliseconds>=150)hasMousePress=true;};
        MouseUp+=(s,e)=>{
            if(e.Button==MouseButtons.Right){Finish("{\"version\":1,\"action\":\"cancel\"}");return;}
            if(e.Button!=MouseButtons.Left || !hasMousePress || pointerClock.ElapsedMilliseconds<150)return;hasMousePress=false;
            if(e.Y>454){Finish("{\"version\":1,\"action\":\"settings\"}");return;}
            var hit=Hit(e.Location);if(hit<0){Close();return;}Pick(hit);RunSelection();
        };
        MouseWheel+=(s,e)=>{scroll+=e.Delta/120f;if(Math.Abs(scroll)>=1){Step(scroll<0?1:-1);scroll=0;}};
        KeyDown+=(s,e)=>{
            if(e.KeyCode==Keys.Escape){Close();e.Handled=true;}
            else if(e.KeyCode==Keys.Return){RunSelection();e.Handled=true;}
            else if(e.KeyCode==Keys.Left || e.KeyCode==Keys.Up){Step(-1);e.Handled=true;}
            else if(e.KeyCode==Keys.Right || e.KeyCode==Keys.Down){Step(1);e.Handled=true;}
            else if(e.KeyCode==Keys.Oem3){active=(active+(e.Shift?request.profiles.Length-1:1))%request.profiles.Length;selected=-1;Invalidate();e.Handled=true;}
        };
        Deactivate+=(s,e)=>Close();
        var expiry=new System.Windows.Forms.Timer();expiry.Interval=(int)(Math.Min(180,Math.Max(15,request.timeoutSeconds<=0?180:request.timeoutSeconds))*1000);
        expiry.Tick+=(s,e)=>{expiry.Stop();Close();};Shown+=(s,e)=>expiry.Start();FormClosed+=(s,e)=>expiry.Dispose();
    }
    void Finish(string response){if(complete)return;complete=true;Response=response;Close();}
    void Pick(int index){if(selected==index)return;selected=index;AccessibleDescription=selected>=0?Items[selected].name:request.profiles[active].name;Invalidate();}
    void Step(int delta){if(Items.Length==0)return;Pick(selected<0?(delta>0?0:Items.Length-1):(selected+delta+Items.Length)%Items.Length);}
    void RunSelection(){if(selected<0 || !Items[selected].available){System.Media.SystemSounds.Beep.Play();return;}Finish("{\"version\":1,\"action\":\"run\",\"profile\":"+active+",\"slot\":"+Items[selected].slot+"}");}
    int Hit(Point point){float dx=point.X-cx,dy=point.Y-cy;var r=Math.Sqrt(dx*dx+dy*dy);if(r<inner||r>outer+7||Items.Length==0)return -1;var angle=(Math.Atan2(dy,dx)+Math.PI/2+Math.PI*2)%(Math.PI*2);return Math.Min(Items.Length-1,(int)(angle/(Math.PI*2/Items.Length)));}
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
            var middle=(-90+step*(n+.5))*Math.PI/180;float lift=selected==n&&!request.reducedMotion?6:0;
            float x=cx+(float)Math.Cos(middle)*lift,y=cy+(float)Math.Sin(middle)*lift,start=-90+step*n+.6f,sweep=step-1.2f;
            using(var path=new GraphicsPath()){
                path.AddArc(x-outer,y-outer,outer*2,outer*2,start,sweep);
                path.AddArc(x-inner,y-inner,inner*2,inner*2,start+sweep,-sweep);path.CloseFigure();
                using(var brush=new SolidBrush(selected==n?Accent:Color.FromArgb(38,43,52)))g.FillPath(brush,path);
                using(var pen=new Pen(selected==n?AccentText:Color.FromArgb(59,66,77),1))g.DrawPath(pen,path);
            }
            if(n<Items.Length){
                var layout=ArcLayout(n,count);
                ArcText(g,(Items[n].slot+1).ToString("00")+" · "+Items[n].mode.ToUpperInvariant(),layout.metaSize,FontStyle.Regular,selected==n?Color.White:Muted,x,y,layout.metaRadius,layout.middle,layout.metaRadius*(float)Math.Max(.1,layout.angleStep-.06));
                using(var font=new Font("Microsoft YaHei UI",layout.nameSize,FontStyle.Bold,GraphicsUnit.Pixel)) {
                    var lines=NameLines(g,Items[n].name,font,layout.maxNameWidth,count>=10?4:2);
                    var radii=lines.Length==1?new float[]{outer-32}:layout.nameRadii.Skip(layout.nameRadii.Length-lines.Length).ToArray();
                    for(int line=0;line<lines.Length;line++)
                        ArcText(g,lines[line],layout.nameSize,FontStyle.Bold,Items[n].available?Ink:Color.Goldenrod,x,y,radii[line],layout.middle,radii[line]*(float)Math.Max(.1,layout.angleStep-.06));
                }
            }
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
    $json = [IO.File]::ReadAllText($RequestPath,[Text.Encoding]::UTF8)
    if ($json.Length -gt 262144) { throw 'Request too large' }
    [Windows.Forms.Application]::EnableVisualStyles()
    $form = New-Object CavalryWheelForm($json)
    [Windows.Forms.Application]::Run($form)
    if ($ResponsePath) {
        $temp=$ResponsePath+'.writing'
        [IO.File]::WriteAllText($temp,$form.Response,(New-Object Text.UTF8Encoding($false)))
        [IO.File]::Move($temp,$ResponsePath)
    } else { [Console]::WriteLine($form.Response) }
} catch {
    $message=(@{version=1;action='error';message=$_.Exception.Message} | ConvertTo-Json -Compress)
    if ($ResponsePath) { [IO.File]::WriteAllText($ResponsePath,$message,(New-Object Text.UTF8Encoding($false))) }
    else { [Console]::WriteLine($message) }
    exit 1
}
