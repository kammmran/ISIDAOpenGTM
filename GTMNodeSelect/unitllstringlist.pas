unit UnitLLStringList;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils;

type
  TIdxDble=record
    Index: integer;
    Value: double;
  end;
  PIdxDble=^TIdxDble;
  TLLSortDirection=(aUp,aDown);

  { TLLStringList }

  TLLStringList = class(TStringList)
  private
    fDirection: TLLSortDirection;
  public
    property Direction: TLLSortDirection read fDirection write fDirection;
    procedure DeleteP(Index: integer);//Delete also pointers
    procedure ClearP();//Clear also pointers
    procedure LLSort();
    constructor Create;
    destructor Destroy; override;
  end;
  function CompareUp(L:TStringList;I1,I2: Integer): integer;//Increasing sort
  function CompareDown(L:TStringList;I1,I2: Integer): integer;//Decreasing sort

implementation

function CompareUp(L: TStringList; I1, I2: Integer): integer;
var
  d1,d2: double;
begin
  d1:=PDouble(L.Objects[I1])^;
  d2:=PDouble(L.Objects[I2])^;
  if d1<d2 then
    Result:=-1
  else if d1>d2 then
    Result:=1
  else Result:=0;
end;

function CompareDown(L: TStringList; I1, I2: Integer): integer;
var
  d1,d2: double;
begin
  d1:=PDouble(L.Objects[I1])^;
  d2:=PDouble(L.Objects[I2])^;
  if d1>d2 then
    Result:=-1
  else if d1<d2 then
    Result:=1
  else Result:=0;
end;

{ TLLStringList }

procedure TLLStringList.DeleteP(Index: integer);
var
  pd: PDouble;
begin
  pd:=PDouble(Objects[Index]);
  if pd<>nil then Dispose(pd);
  inherited Delete(Index);
end;

procedure TLLStringList.ClearP();
var
  i: integer;
  pd: PDouble;
begin
  for i:=0 to Count-1 do begin
    pd:=PDouble(Objects[i]);
    if pd<>nil then Dispose(pd);
  end;
  inherited Clear();
end;

procedure TLLStringList.LLSort();
begin
  if fDirection=aUp then
    CustomSort(@CompareUp)
  else CustomSort(@CompareDown);
end;

constructor TLLStringList.Create;
begin
  fDirection:=aDown;
  inherited Create;
end;

destructor TLLStringList.Destroy;
begin
  Clear();
  inherited Destroy;
end;

end.

