unit unitProc;

{$mode ObjFPC}{$H+}

interface

uses
  Classes, SysUtils, StrUtils, fgl, StdCtrls, Graphics,
  TASeries, TASources, TAChartUtils, utypes, ioSVM, ISIDA_descriptor;

type
  TIntegerList = specialize TFPGList<Integer>;

  { TRsp }

  PRsp = ^TRsp;

  TRsp = record
    Value: double;  // Value of the responsibility
    pValue: double; // Normalized responsibility
    Index: integer; // Index of the corresponding instance - expected to be 1-based
    pIndex: double; // Percentage of the dataset
  end;

  { TlistRsp }

  TlistRsp = class(TList)
  private
    pIsValidpValue, pIsSorted: boolean;
  public
    property IsSorted: boolean read pIsSorted; // Is the list sorted?
    property IsValidpValue: boolean read pIsValidpValue;
    // Is it possible to trust the pValue?
    procedure SetpValue(); // compute the pValue and make them valide
    function Add(d: double; p: integer): integer;
    // Add a responsibility value and store the position of this responsibility (in case of re-ordering or editing of the list)
    procedure Delete(Index: integer);
    procedure Sort(Compare: TListSortCompare);
    procedure UnSort(Compare: TListSortCompare);
    procedure Reset;
    constructor Create;
    destructor Destroy; override;
  end;

function SortPRsp(P1, P2: Pointer): integer;
// Sort according to the responsibility value
function UnSortPRsp(P1, P2: Pointer): integer; // Sort according to the Index value
procedure LoadLLfromRespFile(const sRFileName: string; out aLLvec: TVector);
procedure LoadMxRfromRespFile(const sRFileName: string; out aMxRvec: TVector);
procedure LoadMxRfromRespFile(const sRFileName: string; out aMxRvec: TVector; out aNodeMxRvec: TIntVector);
procedure PlotRCum(sRFleName: string; LS1, LS2: TListChartSource; MmLog: TMemo);
procedure PlotRCum(RVect: TVector; N: integer; LS1, LS2: TListChartSource; MmLog: TMemo);
procedure LoadPrjSeries(PrjFleNme: string; RVec: TVector; LCSMols: TListChartSource;
  PrjToMId: TIntegerList; dRcut: double);
procedure LoadPrjSeries(PrjFleNme, RFleNme: string; LCSMols: TListChartSource;
  PrjToMId: TIntegerList; dRcut: double);

implementation

function SortPRsp(P1, P2: Pointer): integer;
begin
  if PRsp(P1)^.Value > PRsp(P2)^.Value then
    Result := 1
  else if PRsp(P1)^.Value < PRsp(P2)^.Value then
    Result := -1
  else
    Result := 0;
end;

function UnSortPRsp(P1, P2: Pointer): integer;
begin
  if PRsp(P1)^.Index > PRsp(P2)^.Index then
    Result := 1
  else if PRsp(P1)^.Index < PRsp(P2)^.Index then
    Result := -1
  else
    Result := 0;
end;

procedure LoadLLfromRespFile(const sRFileName: string; out aLLvec: TVector);
var
  RSL: TStringList;
  sline, scol1: string;
  v: double;
  i: integer;
begin
  RSL := TStringList.Create;
  RSL.LoadFromFile(sRFileName);
  DimVector(aLLvec,RSL.Count);
  //
  for i := 0 to RSL.Count - 1 do
  begin
    sline := RSL[i]; // parse the file line by line
    scol1 := ExtractWord(1, sline, StdWordDelims);// extract 1st word from the line
    if TryStrToFloat(scol1, v) then  // Check if scol1 is a double and store it in v
    begin
      aLLvec[i+1]:=v;//A likelihood vector is 1 based
    end
    else
    begin
      raise Exception.Create('ERROR DoRun: input file is not a valide *R.svm file');
      Exit;
    end;
  end;
  FreeAndNil(RSL);
end;

procedure LoadMxRfromRespFile(const sRFileName: string; out aMxRvec: TVector);
var
  RSL: TStringList;
  TknSL: LRDsc;
  sline, scol, scol1: string;
  v: double;
  i,j: integer;
begin
  RSL := TStringList.Create;
  TknSL:= LRDsc.Create;
  RSL.LoadFromFile(sRFileName);
  DimVector(aMxRvec,RSL.Count);
  //
  for i := 0 to RSL.Count - 1 do
  begin
    sline := RSL[i]; // parse the file line by line
    TknSL.Clear;
    TknSL.ReadLNSVM(sline);
    aMxRvec[i+1]:=0;
    for j:=0 to TknSL.Count-1 do
    begin
      v:=PRDsc(TknSL.Items[j])^.Cnt;
      if v>aMxRvec[i+1] then aMxRvec[i+1]:=v;
    end;
  end;
  FreeAndNil(RSL);
  FreeAndNil(TknSL);
end;

procedure LoadMxRfromRespFile(const sRFileName: string; out aMxRvec: TVector;
  out aNodeMxRvec: TIntVector);
//Compute from the file sRFileName, the max responsibility and a node where this maximum is reached.
var
  RSL: TStringList;
  TknSL: LRDsc;
  sline, scol, scol1: string;
  v: double;
  i,j: integer;
begin
  RSL := TStringList.Create;
  TknSL:= LRDsc.Create;
  RSL.LoadFromFile(sRFileName);
  DimVector(aMxRvec,RSL.Count);
  DimIntVector(aNodeMxRvec,RSL.Count);
  //
  for i := 0 to RSL.Count - 1 do
  begin
    sline := RSL[i]; // parse the file line by line
    TknSL.Clear;
    TknSL.ReadLNSVM(sline);
    aMxRvec[i+1]:=0;
    aNodeMxRvec[i+1]:=0;
    for j:=0 to TknSL.Count-1 do
    begin
      v:=PRDsc(TknSL.Items[j])^.Cnt;
      if v>aMxRvec[i+1] then begin
        aMxRvec[i+1]:=v;
        aNodeMxRvec[i+1]:=PRDsc(TknSL.Items[j])^.Idx;
      end;
    end;
  end;
  FreeAndNil(RSL);
  FreeAndNil(TknSL);
end;

procedure PlotRCum(sRFleName: string; LS1, LS2: TListChartSource; MmLog: TMemo);
var
  RSL: TStringList;
  RspL: TlistRsp;
  sline, scol1: string;
  v: double;
  i: integer;
begin
  RSL := TStringList.Create;
  RspL := TlistRsp.Create;
  RSL.LoadFromFile(sRFleName); //Load the R.SVM file in memory
  //
  for i := 0 to RSL.Count - 1 do
  begin
    sline := RSL[i]; // parse the file line by line
    scol1 := ExtractWord(1, sline, StdWordDelims);// extract 1st word from the line
    if TryStrToFloat(scol1, v) then  // Check if scol1 is a double and store it in v
    begin
      RspL.Add(v, i + 1);
    end
    else
    begin
      raise Exception.Create('ERROR DoRun: input file is not a valide *R.svm file');
      Exit;
    end;
  end;
  LS1.Clear;
  LS2.Clear;
  RspL.Sort(@SortPRsp);
  RspL.SetpValue();
  for i := 0 to RspL.Count - 1 do
  begin
    LS1.Add(PRsp(RspL.Items[i])^.pValue,(i+1)/RspL.Count);
    LS2.Add(PRsp(RspL.Items[i])^.Value, (i+1)/RspL.Count);
    //LS1.Add(PRsp(RspL.Items[i])^.pIndex, PRsp(RspL.Items[i])^.pValue);
    //LS2.Add(PRsp(RspL.Items[i])^.pIndex, PRsp(RspL.Items[i])^.Value);
  end;
  //
  FreeAndNil(RSL);
  FreeAndNil(RspL);
end;

procedure PlotRCum(RVect: TVector; N: integer; LS1, LS2: TListChartSource;
  MmLog: TMemo);
var
  RSL: TStringList;
  RspL: TlistRsp;
  sline, scol1: string;
  v: double;
  i,ii: integer;

begin
  RspL := TlistRsp.Create;
  //
  ii:=0;
  for i := 1 to N do
  begin
    v:=RVect[i];
    if v>0 then begin
      Inc(ii);
      RspL.Add(v,ii);
    end;
  end;
  LS1.Clear;
  LS2.Clear;
  RspL.Sort(@SortPRsp);
  RspL.SetpValue();
  for i := 0 to RspL.Count - 1 do
  begin
    LS1.Add(PRsp(RspL.Items[i])^.pValue,(i+1)/RspL.Count);
    LS2.Add(PRsp(RspL.Items[i])^.Value, (i+1)/RspL.Count);
  end;
  //
  FreeAndNil(RspL);
end;

procedure LoadPrjSeries(PrjFleNme: string; RVec: TVector;
  LCSMols: TListChartSource; PrjToMId: TIntegerList; dRcut: double);
var
  SLPrj: TStringList;
  i: integer;
  xy: TDoublePoint;
  scol1, sline: string;
  v: double;
  bAccept: boolean;
begin
  bAccept := True;
  LCSMols.Clear;
  PrjToMId.Clear;
  SLPrj := TStringList.Create;
  SLPrj.LoadFromFile(PrjFleNme);
  for i := 1 to SLPrj.Count - 2 do//first and last line are comments
  begin
    v:=RVec[i]; // Responsibility vectors are 1 based
    if (v >= dRcut) then
      bAccept := True
    else
      bAccept := False;
    if bAccept then
    begin
      xy.X := StrToFloat(ExtractWord(1, SLPrj[i], [',']));
      xy.Y := StrToFloat(ExtractWord(2, SLPrj[i], [',']));
      LCSMols.Add(xy.X, xy.Y, IntToStr(i), clYellow);
      PrjToMId.Add(i-1); // Keep track of the molecule ID
    end;
  end;
  FreeAndNil(SLPrj);
end;

procedure LoadPrjSeries(PrjFleNme, RFleNme: string; LCSMols: TListChartSource;
  PrjToMId: TIntegerList; dRcut: double);
var
  SLPrj: TStringList;
  aLR: LRDsc;
  i: integer;
  xy: TDoublePoint;
  scol1, sline: string;
  v: double;
  bAccept: boolean;
  aMxRvec: TVector; // Shouldn't it be recovered from the GTM model rather than from the Responsibility file?
begin
  bAccept := True;
  LCSMols.Clear;
  PrjToMId.Clear;
  SLPrj := TStringList.Create;
  aLR:=LRDsc.Create;
  SLPrj.LoadFromFile(PrjFleNme);
  DimVector(aMxRvec,SLPrj.Count-1);
  LoadMxRfromRespFile(RFleNme,aMxRvec);
  for i:=1 to SLPrj.Count-2 do//first and last line are comments
  begin
    if aMxRvec[i]>=dRcut then bAccept:=True else bAccept:=False;
    if bAccept then
    begin
      xy.X := StrToFloat(ExtractWord(1, SLPrj[i], [',']));
      xy.Y := StrToFloat(ExtractWord(2, SLPrj[i], [',']));
      LCSMols.Add(xy.X, xy.Y, IntToStr(i), clYellow);
      PrjToMId.Add(i-1); // Keep track of the molecule ID
    end;
  end;
  {//To work with likelihood rather than max responsibility
  for i := 1 to SLPrj.Count - 2 do//first and last line are comments
  begin
    sline := SLR[i - 1]; // Responsibility files are 0 based
    scol1 := ExtractWord(1, sline, StdWordDelims);// extract 1st word from the line
    if TryStrToFloat(scol1, v) then
    begin
      if (v >= dRcut) then bAccept := True
      else
        bAccept := False;
    end
    else
    begin
      Exception.Create('ERROR DoRun: input file is not a valide *R.svm file');
      Halt;
    end;
    if bAccept then
    begin
      xy.X := StrToFloat(ExtractWord(1, SLPrj[i], [',']));
      xy.Y := StrToFloat(ExtractWord(2, SLPrj[i], [',']));
      LCSMols.Add(xy.X, xy.Y, IntToStr(i), clYellow);
      PrjToMId.Add(i-1); // Keep track of the molecule ID
    end;
  end;}
  FreeAndNil(SLPrj);
  FreeAndNil(aLR);
end;

{ TlistRsp }

procedure TlistRsp.SetpValue;
var
  rsum, rmin, rmax, rdff: double;
  pItem: PRsp;
  i: integer;
begin
  if not pIsSorted then Sort(@SortPRsp);
  rsum:=0;
  rmin:=PRsp(First)^.Value; // The smallest responsibility in the dataset
  for i:=0 to Count-1 do
  begin
    pItem:=Items[i];
    rsum:=rsum+(pItem^.Value-rmin); // Cumulative implies that all values are >=0
    pItem^.pValue:=rsum;
  end;
  rmin := PRsp(First)^.pValue; // Scaling the cumulative responsibility
  rmax := PRsp(Last)^.pValue;
  rdff := rmax - rmin;
  for i := 0 to Count - 1 do
  begin
    pItem := Items[i];
    pItem^.pValue := (pItem^.pValue - rmin) / rdff;
    pItem^.pIndex := ((i + 1) * 100 / Count); // Index is expected to be 1-based
  end;
end;

function TlistRsp.Add(d: double; p: integer): integer;
  // Add a Rsp pointer to the list - pValues and pIndex are invalide - use SetpValue to validate them
var
  aPRsp: PRsp;
begin
  new(aPRsp);
  aPRsp^.Value := d;
  aPRsp^.Index := p;
  aPRsp^.pValue := 0;
  aPRsp^.pIndex := 0;
  pIsValidpValue := False;
  inherited Add(Pointer(aPRsp));
end;

procedure TlistRsp.Delete(Index: integer);
// Delete a Rsp pointer from the list and free the memory
begin
  dispose(PRsp(Items[Index]));
  inherited Delete(Index);
end;

procedure TlistRsp.Sort(Compare: TListSortCompare);
begin
  pIsSorted := True;
  inherited Sort(Compare);
end;

procedure TlistRsp.UnSort(Compare: TListSortCompare);
begin
  pIsSorted := False;
  inherited Sort(@UnSortPRsp);
end;

procedure TlistRsp.Reset;
// Clear the list and free the memory of all stored pointers
var
  i: integer;
begin
  pIsSorted := False;
  pIsValidpValue := False;
  for i := Count - 1 downto 0 do Delete(i);
  inherited Clear;
end;

constructor TlistRsp.Create;
begin
  pIsSorted := False;
  pIsValidpValue := False;
  inherited Create;
end;

destructor TlistRsp.Destroy;
begin
  Reset;
  inherited Destroy;
end;

end.
