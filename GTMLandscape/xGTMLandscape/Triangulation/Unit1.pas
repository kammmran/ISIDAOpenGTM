unit Unit1;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls,math, StdCtrls;


type
 PTriangle=^TTriangle;
 tDroite=record a,b,c:integer; end;// équation de droite ax+by+c=0
 TTriangle=record
            p1,p2,p3:PPoint;      // les trois sommets
            t1,t2,t3:PTriangle;   // les trois triangles ayant comme arretes communes celles
                                  // oposées respectivement à p1 p2 p3
            d1,d2,d3:tdroite;     // equations des arretes oposées respectivement à p1 p2 p3
            c:tpoint;             // centre du cercle circonscrit
            r:integer;            // rayon au carré du cercle circonscrit

           end;




type
  TForm1 = class(TForm)
    Image1: TImage;
    procedure FormCreate(Sender: TObject);
    procedure Image1MouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure Image1MouseDown(Sender: TObject; Button: TMouseButton;
      Shift: TShiftState; X, Y: Integer);
  private
    { Déclarations privées }
  public
    { Déclarations publiques }
    procedure DrawAllTriangle;
    procedure DrawTriangle(t:ptriangle;cp,cb:tcolor);
    procedure DrawCircleCircon(t:ptriangle);
    procedure DrawAllPoint;
  end;


var
  Form1: TForm1;
  ListePoint:array of ppoint;
  Listetriangle:array of PTriangle;
  maxPoint:integer=0;
  maxTriangle:integer=0;


implementation

{$R *.dfm}

//calcule la distance au carré entre p1 et p2
function distance(p1,p2:ppoint):integer;
begin
 result:=(p1.X-p2.X)*(p1.X-p2.X)+(p1.y-p2.y)*(p1.y-p2.y);
end;

// crée un triangle
function CreateTriangle(p1,p2,p3:ppoint):ttriangle;
var
 diviseur:integer;
 d1,d2,d3:tdroite;
 c:tpoint;
begin
 // calcul de la droite media de [p1;p2]
 d1.a:=-(p1.X-p2.X);
 d1.b:=-(p1.Y-p2.Y);
 d1.c:=-(d1.a*(p1.x+p2.X) div 2) - (d1.b*(p1.y+p2.Y) div 2);
 // calcul de la droite media de [p2;p3]
 d2.a:=-(p2.X-p3.X);
 d2.b:=-(p2.Y-p3.Y);
 d2.c:=-(d2.a*(p2.x+p3.X) div 2) - (d2.b*(p2.y+p3.Y) div 2);
 // calcul de la droite media de [p1;p3]
 d3.a:=-(p1.X-p3.X);
 d3.b:=-(p1.Y-p3.Y);
 d3.c:=-(d3.a*(p1.x+p3.X) div 2) - (d3.b*(p1.y+p3.Y) div 2);

 // calcul du point d'inter de d1 et d2
 diviseur:=d1.a*d2.b-d2.a*d1.b;
 if diviseur=0 then    // = 0 si les trois points sont alignés
  begin
   result.r:=0;
   exit;
  end;

 c.X:=(d1.b*d2.c-d2.b*d1.c) div (diviseur);
 c.y:=(d2.a*d1.c-d1.a*d2.c) div (diviseur);

 result.r:=distance(@c,p1);

 result.p1:=p1;
 result.p2:=p2;
 result.p3:=p3;

 // calcul de la droite [p1;p2]
 d3.a:=-(p1.y-p2.y);
 d3.b:= (p1.x-p2.x);
 d3.c:=-(d3.a*p1.x) - (d3.b*p1.y);
 // calcul de la droite [p2;p3]
 d1.a:=-(p2.y-p3.y);
 d1.b:= (p2.x-p3.x);
 d1.c:=-(d1.a*p2.x) - (d1.b*p2.y);
 // calcul de la droite [p1;p3]
 d2.a:=-(p1.y-p3.y);
 d2.b:= (p1.x-p3.x);
 d2.c:=-(d2.a*p1.x) - (d2.b*p1.y);

 result.d1:=d1;
 result.d2:=d2;
 result.d3:=d3;
 result.t1:=nil;
 result.t2:=nil;
 result.t3:=nil;
 result.c:=c;
end;


// ajoute un point à listepoint
function AddPoint(x,y:integer):ppoint;
begin
 inc(maxPoint);
 setlength(ListePoint,maxPoint);
 new(ListePoint[maxPoint-1]);
 ListePoint[maxPoint-1]^:=point(x,y);
 result:=ListePoint[maxPoint-1];
end;

//ajoute un triangle à listetriangle
function AddTriangle(t:ttriangle):Ptriangle;
begin
 inc(maxtriangle);
 setlength(Listetriangle,maxtriangle);
 new(Listetriangle[maxtriangle-1]);
 Listetriangle[maxtriangle-1]^:=t;
 result:=Listetriangle[maxtriangle-1];
end;

// supprime le triangle n et ses références dans les autres triangles
function DelTriangle(p:ptriangle):ttriangle;
var
 i:integer;
 n:integer;
begin
 // on recherche le triangle dans la liste
 n:=0;
 while (n<maxtriangle) and (listetriangle[n]<>p) do inc(n);
 if n>=maxtriangle then exit;

 // retourne la structure pointé par p
 result:=p^;
 // libert la mémoire
 dispose(listetriangle[n]);
 // efface le triangle dans la liste
 dec(maxtriangle);
 for i:=n to maxtriangle-1 do listetriangle[i]:=listetriangle[i+1];
 setlength(Listetriangle,maxtriangle);
 // remplace les références à p par nil dans le reste de la liste
 for i:=0 to maxtriangle-1 do
  begin
   if listetriangle[i].t1=p then listetriangle[i].t1:=nil;
   if listetriangle[i].t2=p then listetriangle[i].t2:=nil;
   if listetriangle[i].t3=p then listetriangle[i].t3:=nil;
  end;
end;


// est-ce que p1 et p2 sont du même coté de d ?
function ptsMemeCotedeD(p1,p2:ppoint;d:tdroite):boolean;
begin
 result:=(sign(d.a*p1.x+d.b*p1.y+d.c)*sign(d.a*p2.x+d.b*p2.y+d.c)>0)
end;

// p est-il dans t
function PtInTriangle(p:ppoint;t:ptriangle):boolean;
begin
 result:=ptsMemeCotedeD(p,t.p1,t.d1)
     and ptsMemeCotedeD(p,t.p2,t.d2)
     and ptsMemeCotedeD(p,t.p3,t.d3);
end;


// trouve le triangle contenant p
function FindTriangle(p:ppoint):ptriangle;
var
 i:integer;
 t:ptriangle;
begin
 result:=nil;
 for i:=0 to maxtriangle-1 do
  if PtInTriangle(p,listetriangle[i]) then
   begin
    result:=listetriangle[i];
    form1.caption:=inttostr(i);
    exit;
   end;
end;


// retourne le sommet de t qui n'est ni a ni b
function get3rdpoint(t:ptriangle;a,b:ppoint):ppoint;
begin
 result:=nil;
 if t=nil then exit;
 if ((t.p1=a) and (t.p2=b)) or ((t.p1=b) and (t.p2=a)) then result:=t.p3;
 if ((t.p2=a) and (t.p3=b)) or ((t.p2=b) and (t.p3=a)) then result:=t.p1;
 if ((t.p3=a) and (t.p1=b)) or ((t.p3=b) and (t.p1=a)) then result:=t.p2;
end;


//  retourne le triangle voisin de t par l'arete [a,b]
function gettriangle(t:ptriangle;a,b:ppoint):ptriangle;
begin
 result:=nil;
 if t=nil then exit;
 if ((t.p1=a) and (t.p2=b)) or ((t.p1=b) and (t.p2=a)) then result:=t.t3;
 if ((t.p2=a) and (t.p3=b)) or ((t.p2=b) and (t.p3=a)) then result:=t.t1;
 if ((t.p3=a) and (t.p1=b)) or ((t.p3=b) and (t.p1=a)) then result:=t.t2;
end;


procedure actualise_voisin(tv,t:ptriangle;a,b:ppoint);
begin
 if tv=nil then exit;
	if ((tv.p1=a) and (tv.p2=b)) or ((tv.p1=b) and (tv.p2=a)) then tv.t3:=t
	else
  if ((tv.p1=a) and (tv.p3=b)) or ((tv.p1=b) and (tv.p3=a)) then tv.t2:=t
	else tv.t1:=t;
end;


// inverse les deux triangles d'arrete commune [a,b]
procedure swaptriangles(t1,t2:ptriangle;a,b:ppoint);
var
 p1,p2,p3,p4:ppoint;
 v1,v2,v3,v4:ptriangle;
begin
 p1:=a;
 p3:=b;
 p2:=get3rdpoint(t1,a,b);
 p4:=get3rdpoint(t2,a,b);

 v1:=gettriangle(t1,p1,p2);
 v2:=gettriangle(t1,p3,p2);
 v3:=gettriangle(t2,p3,p4);
 v4:=gettriangle(t2,p1,p4);

 t1^:=createtriangle(p1,p2,p4);
 t2^:=createtriangle(p3,p2,p4);


 t1.t1:=t2;
 t1.t2:=v4;
 t1.t3:=v1;

 t2.t1:=t1;
 t2.t2:=v3;
 t2.t3:=v2;
 actualise_voisin(v1,t1,p1,p2);
 actualise_voisin(v2,t2,p2,p3);
 actualise_voisin(v3,t2,p3,p4);
 actualise_voisin(v4,t1,p4,p1);
end;



// applique la 2ème règle de Delaunay, aucun point dans le cercle circonscrit
procedure realigntriangle(t:ptriangle);
var
 t1,t2,t3:ptriangle;
 p1,p2,p3:ppoint;
begin
 if t=nil then exit;

 p1:=get3rdpoint(t.t1,t.p2,t.p3);
 p2:=get3rdpoint(t.t2,t.p1,t.p3);
 p3:=get3rdpoint(t.t3,t.p1,t.p2);

 // test avec les trois voisins
 if (p1<>nil) and (distance(@t.c,p1)<t.r) then
  begin
   swaptriangles(t,t.t1,t.p2,t.p3);
   realigntriangle(t.t2);
   realigntriangle(t.t3);
  end
 else
 if (p2<>nil) and (distance(@t.c,p2)<t.r) then
  begin
   swaptriangles(t,t.t2,t.p1,t.p3);
   realigntriangle(t.t1);
   realigntriangle(t.t3);
  end
 else
 if (p3<>nil) and (distance(@t.c,p3)<t.r) then
  begin
   swaptriangles(t,t.t3,t.p1,t.p2);
   realigntriangle(t.t1);
   realigntriangle(t.t2);
  end;
end;


// atribut les triangles t1,t2,t3 à t
procedure defineTriangle(t,t1,t2,t3:ptriangle);
begin
 t^.t1:=t1; t^.t2:=t2; t^.t3:=t3;
end;

// applique la 1er règle de Delaunay, detruire et construire
procedure Algorythm_Delaunay(x,y:integer);
var
 ptri:ptriangle;
 oldtri:ttriangle;   // ancien triangle
 t1,t2,t3:ptriangle; // les trois nouveaux triangles
 p1,p2,p3,p4:ppoint; // les trois sommets + le nouveau au centre
 v1,v2,v3:ptriangle; // les trois voisins
begin
 p4:=addpoint(x,y);
 ptri:=findtriangle(p4);
 //supprime le triangle précédent
 oldtri:=deltriangle(ptri);

 // récupère les trois sommets et les trois voisins
 p1:=oldtri.p1;
 p2:=oldtri.p2;
 p3:=oldtri.p3;

 v1:=oldtri.t1;
 v2:=oldtri.t2;
 v3:=oldtri.t3;

 // en construit 3 à la place
 t1:=addtriangle(createtriangle(p4,p2,p3));
 t2:=addtriangle(createtriangle(p4,p3,p1));
 t3:=addtriangle(createtriangle(p4,p1,p2));


 // attribut les triangles voisins à t1 t2 et t3
 defineTriangle(t1,v1,t2,t3);
 defineTriangle(t2,v2,t3,t1);
 defineTriangle(t3,v3,t1,t2);

 // fait pointer les voisins vers les trois triangles
 if v1<>nil then actualise_voisin(v1,t1,t1.p2,t1.p3);
 if v2<>nil then actualise_voisin(v2,t2,t2.p2,t2.p3);
 if v3<>nil then actualise_voisin(v3,t3,t3.p2,t3.p3);

 // réaligne les 3 triangles en appliquant la 2ème règle
 realigntriangle(t1);
 realigntriangle(t2);
 realigntriangle(t3);
end;


// dessine les cercles circonscrit aux triangles
procedure TForm1.DrawAllPoint;
var
 i:integer;
 p:tpoint;
begin
 image1.canvas.Brush.Style:=bssolid;
 image1.canvas.Brush.color:=claqua;
 image1.Canvas.Pen.Color:=clblack;
 for i:=0 to maxpoint-1 do
  begin
   p:=listepoint[i]^;
   image1.Canvas.Ellipse(p.X-4,p.y-4,p.X+4,p.y+4);
  end;
end;

// dessine les cercles circonscrit aux triangles
procedure TForm1.DrawCircleCircon(t:ptriangle);
var
 r:integer;
begin
 image1.canvas.Brush.Style:=bsclear;
 image1.Canvas.Pen.Color:=clblack;
 r:=round(sqrt(t.r));
 image1.Canvas.Ellipse(t.c.X-r,t.c.Y-r,t.c.X+r,t.c.Y+r);
end;


// dessine le triangle t dans image1.canvas avec les couleur cp et cb
procedure TForm1.DrawTriangle(t:ptriangle;cp,cb:tcolor);
var
 points:array[0..2] of tpoint;
begin
 if t=nil then exit;
 points[0]:=t.p1^;
 points[1]:=t.p2^;
 points[2]:=t.p3^;
 image1.Canvas.pen.color:=cp;
 image1.Canvas.brush.color:=cb;
 image1.Canvas.Polygon(points);
end;

// dessine tout les triangles dans image1.canvas
procedure TForm1.DrawAllTriangle;
var
 i:integer;
begin
 image1.Canvas.Brush.Style:=bssolid;
 image1.Canvas.Brush.color:=clwhite;
 image1.Canvas.FillRect(image1.ClientRect);
 for i:=0 to maxtriangle-1 do
   DrawTriangle(listetriangle[i],clblack,clwhite);
end;


procedure TForm1.FormCreate(Sender: TObject);
var
 p1,p2,p3,p4:ppoint;
begin
 // crée les quatres points, coins de l'image
 p1:=addpoint(0,0);
 p2:=addpoint(image1.Width-1,0);
 p3:=addpoint(0,image1.Height-1);
 p4:=addpoint(image1.Width-1,image1.Height-1);

 // cre les deux triangles initiaux
 addtriangle(createtriangle(p1,p2,p3));
 addtriangle(createtriangle(p2,p3,p4));

 // lie les deux premiers triangles
 listetriangle[0].t1:=listetriangle[1];
 listetriangle[1].t3:=listetriangle[0];
end;


procedure TForm1.Image1MouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var
 t:ptriangle;
 p:tpoint;
begin
 // dessine tous les triangles
 DrawAllTriangle;
 p:=point(x,y);
 t:=findtriangle(@p);
 if t=nil then exit;
 // puis le triangle selectionné en jaune et les trois voisins en vert
 drawtriangle(t.t1,claqua,clgreen);
 drawtriangle(t.t2,claqua,clgreen);
 drawtriangle(t.t3,claqua,clgreen);
 drawtriangle(t,clred,clyellow);
 DrawAllPoint;
 DrawCircleCircon(t);
end;

procedure TForm1.Image1MouseDown(Sender: TObject; Button: TMouseButton;
  Shift: TShiftState; X, Y: Integer);
begin
 Algorythm_Delaunay(x,y);
 DrawAllTriangle;
 DrawAllPoint;
end;


end.
