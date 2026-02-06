unit uDelaunay;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, contnrs, fgl, Math;

type
  TStrLine = record
    a, b, c: double;
  end;// line equation a*x+b*y+c=0

  { T2DPoint }

  T2DPoint = class(TObject)
  private
    fx, fy: double;
    fx2, fy2: double; //squared coordinates
    procedure SetX(val: double);
    procedure SetY(val: double);
  public
    property x: double read fx write SetX;
    property y: double read fy write SetY;
    property x2: double read fx2;
    property y2: double read fy2;
    procedure SetXY(valx, valy: double);
    constructor Create;
    destructor Destroy; override;
  end;

  { T2DTriangle - A triangle does not own its points}

  T2DTriangle = class(TObject)
  private
    fp1, fp2, fp3: T2DPoint; // triangle summits
    ft1, ft2, ft3: T2DTriangle; // triangles sharing the edge opposite to p1, p2 and p3
  public
    procedure UpdateNeighbour(oldt, newt: T2DTriangle);
    procedure SetTriangle(p1, p2, p3: T2DPoint);
    procedure SetNeighbors(t1, t2, t3: T2DTriangle);
    function GetOppositeSummit(p: T2DPoint): T2DPoint;
    procedure GetOppositeSummit(p: T2DPoint; out popp, pface1, pface2: T2DPoint);
    function GetThirdPoint(pa, pb: T2DPoint): T2DPoint;
    function GetNeighbour(pa, pb: T2DPoint): T2DTriangle;
    function HasEdge(ap1, ap2: T2DPoint): boolean;
    property p1: T2DPoint read fp1 write fp1;
    property p2: T2DPoint read fp2 write fp2;
    property p3: T2DPoint read fp3 write fp3;
    property t1: T2DTriangle read ft1 write ft1; //Neighbor sharing p2,p3
    property t2: T2DTriangle read ft2 write ft2; //Neighbor sharing p3,p1
    property t3: T2DTriangle read ft3 write ft3; //Neighbor sharing p1,p2
    constructor Create;
    destructor Destroy; override;
  end;

  { TDelaunay }

  TDelaunay = class(TObject)
  private
    faPointList: TObjectList;
    faTriangleList: TObjectList;
    function CreateTriangle(p1, p2, p3: T2DPoint): T2DTriangle;
  public
    procedure AddPoint(p: T2DPoint);
    procedure AddPoint(x, y: double);
    procedure Closest2Points(p: T2DPoint; out p1, p2: T2DPoint);
    function SearchTriangleByPoint(p: T2DPoint): T2DTriangle;
    function SearchTriangleByEdge(p1, p2: T2DPoint): T2DTriangle;
    procedure MkDelaunay(t: T2DTriangle);
    procedure FlipTriangles(t1, t2: T2DTriangle; pa, pb: T2DPoint);
    property aPointList: TObjectList read faPointList write faPointList;
    property aTriangleList: TObjectList read faTriangleList write faTriangleList;
    constructor Create;
    destructor Destroy; override;
  end;

function orientTriangle(var t: T2DTriangle): double; //return surface
function IsInCircumCircle(p: T2DPoint; t: T2DTriangle): boolean;

implementation

{ T2DTriangle }

procedure T2DTriangle.UpdateNeighbour(oldt, newt: T2DTriangle);
begin
  if oldt = ft1 then
    ft1 := newt
  else if oldt = ft2 then
    ft2 := newt
  else if oldt = ft3 then
    ft3 := newt;
  //if oldt not found, do nothing
end;

procedure T2DTriangle.SetTriangle(p1, p2, p3: T2DPoint);
begin
  fp1 := p1;
  fp2 := p2;
  fp3 := p3;
end;

procedure T2DTriangle.SetNeighbors(t1, t2, t3: T2DTriangle);
//Be sure that t1 faces edge p1, t2 faces p2, t3 faces p3.
begin
  ft1:=nil;
  ft2:=nil;
  ft3:=nil;
  //set t1
  if t1<>nil then
  begin
    if t1.HasEdge(fp1,fp2) then
    begin
      if ft3=nil then ft3:=t1;
    end else if t1.HasEdge(fp2,fp3) then
    begin
      if ft1=nil then ft1:=t1;
    end
    else if t1.HasEdge(fp3,fp1) then
    begin
      if ft2=nil then ft2:=t1;
    end;
  end;
  //set t2
  if t2<>nil then
  begin
    if t2.HasEdge(fp1,fp2) then
    begin
      if ft3=nil then ft3:=t2;
    end else if t2.HasEdge(fp2,fp3) then
    begin
      if ft1=nil then ft1:=t2;
    end
    else if t2.HasEdge(fp3,fp1) then
    begin
      if ft2=nil then ft2:=t2;
    end;
  end;
  //set t3
  if t3<>nil then
  begin
    if t3.HasEdge(fp1,fp2) then
    begin
      if ft3=nil then ft3:=t3;
    end else if t3.HasEdge(fp2,fp3) then
    begin
      if ft1=nil then ft1:=t3;
    end
    else if t3.HasEdge(fp3,fp1) then
    begin
      if ft2=nil then ft2:=t3;
    end;
  end;
end;

function T2DTriangle.GetOppositeSummit(p: T2DPoint): T2DPoint;
  //Returns the summit of triangle opposite to p or nil if p is interior to triangle
var
  v1, v2: T2DPoint;
  det12p, det123: double;
begin
  Result := nil;
  det123 := fp1.x * fp2.y - fp1.x * fp3.y - fp1.y * fp2.x + fp1.y * fp3.x + fp2.x * fp3.y - fp2.y * fp3.x;
  det12p := fp1.x * fp2.y - fp1.x * p.y - fp1.y * fp2.x + fp1.y * p.x + fp2.x * p.y - fp2.y * p.x;
  if (det12p * det123 < 0) then
    //(P1P2) separates P3 and P if (P1P2P3) and (P1P2P) are oriented in opposite directions
    Result := fp3
  else
  begin
    det12p := fp2.x * fp3.y - fp2.x * p.y - fp2.y * fp3.x + fp2.y * p.x + fp3.x * p.y - fp3.y * p.x;
    if (det12p * det123 < 0) then
      //(P2P3) separates P1 and P if (P2P3P1) and (P2P3P) are oriented in opposite directions
      Result := fp1
    else
    begin
      det12p := fp3.x * fp1.y - fp3.x * p.y - fp3.y * fp1.x + fp3.y * p.x + fp1.x * p.y - fp1.y * p.x;
      if (det12p * det123 < 0) then
        //(P3P1) separates P2 and P if (P3P1P2) and (P3P1P) are oriented in opposite directions
        Result := fp2
      else
        Result := nil;
    end;
  end;
end;

procedure T2DTriangle.GetOppositeSummit(p: T2DPoint;
  out popp, pface1, pface2: T2DPoint);
//Return the opposite summit and the segment facing the point p
begin
  popp := GetOppositeSummit(p);
  if popp = nil then
  begin
    pface1 := nil;
    pface2 := nil;
  end
  else
  begin
    if popp = fp1 then
    begin
      pface1 := fp2;
      pface2 := fp3;
    end
    else if popp = fp2 then
    begin
      pface1 := fp3;
      pface2 := fp1;
    end
    else if popp = fp3 then
    begin
      pface1 := fp1;
      pface2 := fp2;
    end;
  end;
end;

function T2DTriangle.GetThirdPoint(pa, pb: T2DPoint): T2DPoint;
  //Given pa and pb return the third point of the triangle
begin
  Result := nil;
  if ((pa = fp1) and (pb = fp2)) or ((pa = fp2) and (pb = fp1)) then
    Result := fp3
  else if ((pa = fp2) and (pb = fp3)) or ((pa = fp3) and (pb = fp2)) then
    Result := fp1
  else if ((pa = fp3) and (pb = fp1)) or ((pa = fp1) and (pb = fp3)) then
    Result := fp2;
end;

function T2DTriangle.GetNeighbour(pa, pb: T2DPoint): T2DTriangle;
var
  s: T2DPoint;
begin
  Result := nil;
  s := GetThirdPoint(pa, pb);
  if (s <> nil) then
    if fp1 = s then
      Result := ft1
    else if fp2 = s then
      Result := ft2
    else
      Result := ft3;
end;

function T2DTriangle.HasEdge(ap1, ap2: T2DPoint): boolean;
  //Check if an edge belong to the triangle
begin
  if (ap1 = fp1) then
  begin
    if (ap2 = fp2) or (ap2 = fp3) then
      Result := True;
  end
  else if (ap1 = fp2) then
  begin
    if (ap2 = fp1) or (ap2 = fp3) then
      Result := True;
  end
  else if (ap1 = fp3) then
  begin
    if (ap2 = fp2) or (ap2 = fp1) then
      Result := True;
  end
  else
    Result := False;
end;

constructor T2DTriangle.Create;
begin
  fp1 := nil;
  fp2 := nil;
  fp3 := nil;
  ft1 := nil;
  ft2 := nil;
  ft3 := nil;
end;

destructor T2DTriangle.Destroy;
begin
  // A triangle does not own its points
  inherited Destroy;
end;

{ T2DPoint }

procedure T2DPoint.SetX(val: double);
begin
  fx := val;
  fx2 := sqr(val);
end;

procedure T2DPoint.SetY(val: double);
begin
  fy := val;
  fy2 := sqr(val);
end;

procedure T2DPoint.SetXY(valx, valy: double);
begin
  SetX(valx);
  SetY(valy);
end;

constructor T2DPoint.Create;
begin
  fx := 0;
  fy := 0;
  fx2 := 0;
  fy2 := 0;
end;

destructor T2DPoint.Destroy;
begin
  inherited Destroy;
end;

function orientTriangle(var t: T2DTriangle): double; //return surface
var
  det: double;
  ptmp: T2DPoint;
begin
  with t do
  begin
    det := (p2.x - p1.x) * (p3.y - p2.y) - (p3.x - p2.x) * (p2.y - p1.y);
    //det>0 if triangle is anti-clockwise
    if det < 0 then //p2<->p3 to orient the triangle
    begin
      //writeln('--orient-- det='+FloatToStr(det));
      //writeln('>> ('+FloatToStr(t.p1.x)+','+FloatToStr(t.p1.y)+') ('+FloatToStr(t.p2.x)+','+FloatToStr(t.p2.y)+') ('+FloatToStr(t.p3.x)+','+FloatToStr(t.p3.y)+')');
      ptmp := p3;
      p3 := p2;
      p2 := ptmp;
      //writeln('<< ('+FloatToStr(t.p1.x)+','+FloatToStr(t.p1.y)+') ('+FloatToStr(t.p2.x)+','+FloatToStr(t.p2.y)+') ('+FloatToStr(t.p3.x)+','+FloatToStr(t.p3.y)+')');
    end
    else
    begin
      //writeln('--orient-- det='+FloatToStr(det));
      //writeln('!! ('+FloatToStr(t.p1.x)+','+FloatToStr(t.p1.y)+') ('+FloatToStr(t.p2.x)+','+FloatToStr(t.p2.y)+') ('+FloatToStr(t.p3.x)+','+FloatToStr(t.p3.y)+')');
    end;
  end;
  Result := abs(det) / 2;
end;

function IsInCircumCircle(p: T2DPoint; t: T2DTriangle): boolean;
var
  det: double;
begin
  with t do
    det := p1.x * p2.y * p3.x2 + p1.x * p2.y * p3.y2 - p1.x * p2.y * p.x2 - p1.x * p2.y * p.y2 +
      p1.x * p3.y * p.x2 + p1.x * p3.y * p.y2 - p1.x * p2.x2 * p3.y + p1.x * p2.x2 * p.y -
      p1.x * p2.y2 * p3.y + p1.x * p2.y2 * p.y - p1.x * p3.x2 * p.y - p1.x * p3.y2 * p.y -
      p1.y * p2.x * p3.x2 - p1.y * p2.x * p3.y2 + p1.y * p2.x * p.x2 + p1.y * p2.x * p.y2 -
      p1.y * p3.x * p.x2 - p1.y * p3.x * p.y2 + p1.y * p2.x2 * p3.x - p1.y * p2.x2 * p.x +
      p1.y * p2.y2 * p3.x - p1.y * p2.y2 * p.x + p1.y * p3.x2 * p.x + p1.y * p3.y2 * p.x -
      p2.x * p3.y * p.x2 - p2.x * p3.y * p.y2 + p2.x * p3.x2 * p.y + p2.x * p3.y2 * p.y +
      p2.y * p3.x * p.x2 + p2.y * p3.x * p.y2 - p2.y * p3.x2 * p.x - p2.y * p3.y2 * p.x +
      p1.x2 * p2.x * p3.y - p1.x2 * p2.x * p.y - p1.x2 * p2.y * p3.x + p1.x2 * p2.y * p.x +
      p1.x2 * p3.x * p.y - p1.x2 * p3.y * p.x + p1.y2 * p2.x * p3.y - p1.y2 * p2.x * p.y -
      p1.y2 * p2.y * p3.x + p1.y2 * p2.y * p.x + p1.y2 * p3.x * p.y - p1.y2 * p3.y * p.x -
      p2.x2 * p3.x * p.y + p2.x2 * p3.y * p.x - p2.y2 * p3.x * p.y + p2.y2 * p3.y * p.x;
  if det > 0 then
    Result := True
  else
    Result := False;
end;

{ TDelaunay }

function TDelaunay.CreateTriangle(p1, p2, p3: T2DPoint): T2DTriangle;
var
  atriangle: T2DTriangle;
  surf: double;
begin
  atriangle := T2DTriangle.Create;
  atriangle.SetTriangle(p1, p2, p3);
  surf := orientTriangle(atriangle);
  if surf > 0 then //Add triangle
  begin
    faTriangleList.Add(TObject(atriangle));
    Result := atriangle;
  end
  else //triangle is flat->ignore
  begin
    FreeAndNil(atriangle);
    Result := nil;
  end;
end;

procedure TDelaunay.AddPoint(p: T2DPoint);
var
  i, tindex: integer;
  t, t1, t2, t3: T2DTriangle;
  newt, newt1, newt2, newt3: T2DTriangle;
  p1, p2, p3, ptmp: T2DPoint;
  d1, d2, dtmp: double;
  bFound: boolean;
begin
  if faPointList.Count < 2 then //Not enough points to have a triangle
  begin
    faPointList.Add(p);
  end
  else
  begin
    Closest2Points(p, p1, p2);
    if (p1 <> nil) and (p2 <> nil) then
      // the new point does not overlap with any other point
    begin
      faPointList.Add(TObject(p));
      t := SearchTriangleByPoint(p);
      if (t <> nil) then
      begin
        //Get summits
        p1 := t.p1;
        p2 := t.p2;
        p3 := t.p3;
        //Get neigbors
        t1 := t.t1;
        t2 := t.t2;
        t3 := t.t3;
        //Create new triangles
        newt1 := CreateTriangle(p, p2, p3);
        newt2 := CreateTriangle(p, p3, p1);
        newt3 := CreateTriangle(p, p1, p2);
        //Set neighboring triangles: p2,p3->t1; p3,p1->t2; p1,p2->t3
        newt1.SetNeighbors(t1, newt2, newt3);
        newt2.SetNeighbors(t2, newt3, newt1);
        newt3.SetNeighbors(t3, newt1, newt2);
        //Update the neighbouring triangles
        if t1 <> nil then
          t1.UpdateNeighbour(t, newt1);
        if t2 <> nil then
          t2.UpdateNeighbour(t, newt2);
        if t3 <> nil then
          t3.UpdateNeighbour(t, newt3);
        //Swap edge
        MkDelaunay(newt1);
        MkDelaunay(newt2);
        MkDelaunay(newt3);
        //Remove this triangle
        faTriangleList.Remove(TObject(t));
      end
      else
      begin//p is exterior to t, only one triangle is added to triangulation
        newt := CreateTriangle(p1, p2, p);
        bFound := False;
        i := 0;
        while (i < faTriangleList.Count) and (not bFound) do
        begin
          t := faTriangleList.Items[i] as T2DTriangle;
          if t.HasEdge(p1, p2) and (t <> newt) then
            bFound := True;
          Inc(i);
        end;
        if bFound then
          newt.SetNeighbors(nil, nil, t);
        faTriangleList.Add(newt);
      end;
    end;
  end;
  {for i:=0 to faTriangleList.Count-1 do
  begin
    t:=faTriangleList.Items[i] as T2DTriangle;
    t1:=t.t1;
    t2:=t.t2;
    t3:=t.t3;
    writeln('t : '+'('+FloatToStr(t.p1.x)+','+FloatToStr(t.p1.y)+') ('+FloatToStr(t.p2.x)+','+FloatToStr(t.p2.y)+') ('+FloatToStr(t.p3.x)+','+FloatToStr(t.p3.y)+')');
    if t.t1 <> nil then
      writeln('>t1: '+'('+FloatToStr(t1.p1.x)+','+FloatToStr(t1.p1.y)+') ('+FloatToStr(t1.p2.x)+','+FloatToStr(t1.p2.y)+') ('+FloatToStr(t1.p3.x)+','+FloatToStr(t1.p3.y)+')');
    if t.t2 <> nil then
      writeln('>t2: '+'('+FloatToStr(t2.p1.x)+','+FloatToStr(t2.p1.y)+') ('+FloatToStr(t2.p2.x)+','+FloatToStr(t2.p2.y)+') ('+FloatToStr(t2.p3.x)+','+FloatToStr(t2.p3.y)+')');
    if t.t3 <> nil then
      writeln('>t3: '+'('+FloatToStr(t3.p1.x)+','+FloatToStr(t3.p1.y)+') ('+FloatToStr(t3.p2.x)+','+FloatToStr(t3.p2.y)+') ('+FloatToStr(t3.p3.x)+','+FloatToStr(t3.p3.y)+')');
    writeln('----');
  end;
  writeln('******');}

end;

procedure TDelaunay.AddPoint(x, y: double);
var
  p: T2DPoint;
begin
  p := T2DPoint.Create;
  p.x := x;
  p.y := y;
  AddPoint(p);
end;

procedure TDelaunay.Closest2Points(p: T2DPoint; out p1, p2: T2DPoint);
var
  i: integer;
  d1, d2, dtmp: double;
  ptmp: T2DPoint;
begin
  //search for p1 and p2 the two closest point to p
  p1 := faPointList.Items[0] as T2DPoint;
  p2 := faPointList.items[1] as T2DPoint;
  d1 := sqr(p1.x - p.x) + sqr(p1.y - p.y);
  d2 := sqr(p2.x - p.x) + sqr(p2.y - p.y);
  if d1 > d2 then // swap so that p1 closer to p than p2
  begin
    dtmp := d1;
    ptmp := p1;
    d1 := d2;
    p1 := p2;
    d2 := dtmp;
    p2 := ptmp;
  end;
  for i := 2 to faPointList.Count - 1 do //do not check the last point added
  begin
    ptmp := faPointList.Items[i] as T2DPoint;
    dtmp := sqr(ptmp.x - p.x) + sqr(ptmp.y - p.y);
    if dtmp > 0 then
    begin
      if dtmp < d1 then
      begin
        d2 := d1;
        p2 := p1;
        d1 := dtmp;
        p1 := ptmp;
      end
      else if dtmp < d2 then
      begin
        d2 := dtmp;
        p2 := ptmp;
      end;
    end;
  end;
  if (d1 = 0) or (d2 = 0) then // p overlaps with existing points
  begin
    p1 := nil;
    p2 := nil;
  end;
end;

function TDelaunay.SearchTriangleByPoint(p: T2DPoint): T2DTriangle;
var
  i: integer;
  bFound: boolean;
  t: T2DTriangle;
begin
  t := nil;
  i := 0;
  bFound := False;
  while (i < faTriangleList.Count) and (not bFound) do
  begin
    t := faTriangleList.Items[i] as T2DTriangle;
    bFound := IsInCircumCircle(p, t);
    Inc(i);
  end;
  Result := t;
end;

function TDelaunay.SearchTriangleByEdge(p1, p2: T2DPoint): T2DTriangle;
  //Find a triangle with edge p1,p2. Return only one answer among possible ones
var
  i: integer;
  bFound: boolean;
  t: T2DTriangle;
begin
  i := 0;
  bFound := False;
  while (i < faTriangleList.Count) and (not bFound) do
  begin
    t := faTriangleList.Items[i] as T2DTriangle;
    if (p1 = t.p1) then
    begin
      if (p2 = t.p2) or (p2 = t.p3) then
        bFound := True;
    end
    else if (p1 = t.p2) then
    begin
      if (p2 = t.p1) or (p2 = t.p3) then
        bFound := True;
    end
    else if (p1 = t.p3) then
    begin
      if (p2 = t.p1) or (p2 = t.p2) then
        bFound := True;
    end;
    Inc(i);
  end;
  if bFound then
    Result := t
  else
    Result := nil;
end;

procedure TDelaunay.MkDelaunay(t: T2DTriangle);
var
  t1, t2, t3: T2DTriangle;
  p1, p2, p3: T2DPoint;
begin
  p1 := nil;
  p2 := nil;
  p3 := nil;
  if t <> nil then
  begin
    //Get the 3 summits of adjacent triangles
    if (t.t1 <> nil) then
      p1 := t.t1.GetThirdPoint(t.p2, t.p3);
    if (t.t2 <> nil) then
      p2 := t.t2.GetThirdPoint(t.p1, t.p3);
    if (t.t3 <> nil) then
      p3 := t.t3.GetThirdPoint(t.p1, t.p2);
    //Flip those triangles that are no longer Delaunay
    if (p1 <> nil) and IsInCircumCircle(p1, t) then
    begin
      FlipTriangles(t, t.t1, t.p2, t.p3);
      MkDelaunay(t.t2);
      MkDelaunay(t.t3);
    end
    else if (p2 <> nil) and IsInCircumCircle(p2, t) then
    begin
      FlipTriangles(t, t.t2, t.p3, t.p1);
      MkDelaunay(t.t3);
      MkDelaunay(t.t1);
    end
    else if (p3 <> nil) and IsInCircumCircle(p3, t) then
    begin
      FlipTriangles(t, t.t3, t.p1, t.p2);
      MkDelaunay(t.t1);
      MkDelaunay(t.t2);
    end;
  end;
end;

procedure TDelaunay.FlipTriangles(t1, t2: T2DTriangle; pa, pb: T2DPoint);
//t1 and t2 are replaced by Delanay triangles
var
  p1, p2, p3, p4: T2DPoint;
  n1, n2, n3, n4: T2DTriangle;
  newt1, newt2: T2DTriangle;
begin
  p1 := pa;
  p3 := pb;
  p2 := t1.GetThirdPoint(pa, pb);
  p4 := t2.GetThirdPoint(pa, pb);

  n1 := t1.GetNeighbour(p1, p2);
  n2 := t1.GetNeighbour(p2, p3);
  n3 := t2.GetNeighbour(p3, p4);
  n4 := t2.GetNeighbour(p4, p1);

  newt1 := CreateTriangle(p1, p2, p4);
  newt2 := CreateTriangle(p3, p2, p4);

  newt1.SetNeighbors(newt2, n4, n1);
  newt2.SetNeighbors(newt1, n3, n2);

  n1.UpdateNeighbour(t1, newt1);
  n2.UpdateNeighbour(t1, newt2);
  n3.UpdateNeighbour(t2, newt2);
  n4.UpdateNeighbour(t2, newt1);

  faTriangleList.Remove(TObject(t1));
  faTriangleList.Remove(TObject(t2));

  faTriangleList.Add(TObject(newt1));
  faTriangleList.Add(TObject(newt2));
end;

constructor TDelaunay.Create;
begin
  faPointList := TObjectList.Create;
  faTriangleList := TObjectList.Create;
  faPointList.OwnsObjects := True;
  faTriangleList.OwnsObjects := True;
end;

destructor TDelaunay.Destroy;
begin
  FreeAndNil(faPointList);
  FreeAndNil(faTriangleList);
  inherited Destroy;
end;

end.
