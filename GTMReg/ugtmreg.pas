unit UGTMReg;

{$mode objfpc}{$H+}
//Macro so that at compile time, if GUI is used, writeln will store
//strings into a SLog TStringList and if not, it is directed to stdout.
//{$MACRO ON}
//{$DEFINE WRITELN:={$IFDEF GUI}SLog.Add{$ELSE}writeln{$ENDIF}}
//{$DEFINE APP_PROCESS:={$IFDEF GUI}Application.ProcessMessages{$ENDIF}}
interface

uses
  Classes, SysUtils, UGTMBase, UGTMXML, ulinalg, utypes, math;

type
TAoD = array of double;

{ TGTMReg }

TGTMReg = class(TGTMBase)
private
    //fMinRspLS: double; //Min responsability value to count for landscape
    faDensity: TAoD; //density
    faLandscape: TAoD; //landscape
    faLandscape2: TAoD; //landscape of property standard dev
    faCoherence: TAoD; //landscape of coherence scores - DOI: 10.1021/acs.jcim.0c00998
    faTrustworthiness: TAoD; //landscape of trustworthiness - idem
    //fnNode: integer; //Number of nodes on the map; must be set reading a GTM model
    fnMol0, fnMol1: integer; //# of all molecule, # of molecules contributing to landscape
    fdMinRspAD: double;//Min (sum) responsability value to be in applicability domain
    fdMinRspToNode: double; //Minimum responsibility to contribute to a node
    fdMinDensityLS: double; //Minimum density value for a node to be inside, between 0 and 1
    fbFinalize: boolean;//Density and landscape are ready or not
    fdPrpMean, fdPrpStdDev: double; //Mean and Std. Dev. value of the property of contributing molecules
    fPrpName: shortstring; //Short name for the property (max 255 char)
    fdPrpMin, fdPrpMax, fdPrpRng: double; // Min, max and range of property values
    fdTtau,fdTalpha,fdTbeta,fdTT: double; //Trustworthiness parameters; tau=offset, alpha=density exponent, beta=coherence exponent, TT=AD threshold
    function GetCoherence(Idx: integer): double;
    function GetDensity(Idx: integer): double;
    function GetLandscape(Idx: integer): double;
    function GetLandscape2(Idx: integer): double;
    function GetTrustworthiness(Idx: integer): double;
    procedure SetCoherence(Idx: integer; AValue: double);
    procedure SetDensity(Idx: integer; AValue: double);
    procedure SetLandscape(Idx: integer; AValue: double);
    procedure SetLandscape2(Idx: integer; AValue: double);
    procedure SetTrustworthiness(Idx: integer; AValue: double);

public
  //property MinRspLS: double read fMinRspLS write fMinRspLS;
  property Density[Idx: integer]: double read GetDensity write SetDensity;
  property Landscape[Idx: integer]: double read GetLandscape write SetLandscape;
  property Landscape2[Idx: integer]: double read GetLandscape2 write SetLandscape2;
  property Coherence[Idx: integer]: double read GetCoherence write SetCoherence;
  property Trustworthiness[Idx: integer]: double read GetTrustworthiness write SetTrustworthiness;
  property MinRspAD: double read fdMinRspAD write fdMinRspAD;//The minimal sum of responsibility on mapped nodes (with a landscape value)
  property MinRspToNode: double read fdMinRspToNode write fdMinRspToNode;
  property MinDensityLS: double read fdMinDensityLS write fdMinDensityLS;
  property PrpMean: double read fdPrpMean write fdPrpMean;
  property PrpStdDev: double read fdPrpStdDev write fdPrpStdDev;
  property nMol0: integer read fnMol0;
  property nMol1: integer read fnMol1;
  property PrpName: ShortString read fPrpName write fPrpName;
  property dPrpMin: double read fdPrpMin write fdPrpMin;
  property dPrpMax: double read fdPrpMax write fdPrpMax;
  property dPrpRng: double read fdPrpRng write fdPrpRng;
  property dTtau: double read fdTtau write fdTtau;
  property dTalpha: double read fdTalpha write fdTalpha;
  property dTbeta: double read fdTbeta write fdTbeta;
  property dTT: double read fdTT write fdTT;
  procedure AddMolecule(sRes:string);//update density and landscape with responsibilities as SVM strings, property in first column
  procedure AddMolecule(sRes,sPrp:string);//update density and landscape with responsibilities as SVM strings and property as string
  procedure AddMolecule(sRes:string; dPrp: double);//update density and landscape with responsibilities as SVM strings and property as double
  procedure AddMolecule(aRMol: TAoD; dprp: double);//update density and landscape with responsibilities of a molecule and a property value
  function hmgDensity(): double; //Homogeneous density
  function minDensity(): double; //minimal density value
  function maxDensity(): double; //maximal density value
  function PredMol(aRes: TAoD; out dmean, dstdev, dTrst: double; out bInAD: boolean): double;
  function GetDensityXYZ(): TMatrix;
  function GetLandscapeXYZ(): TMatrix;
  function GetLandscape2XYZ(): TMatrix;
  procedure ReadGTMModel(xmlfle: string);
  procedure DoInitialize(); //Initialize the GTMReg using ancestor information
  procedure DoFinalize;
  constructor Create;
  destructor Destroy; override;
end;
implementation

{ TGTMReg }

function TGTMReg.GetDensity(Idx: integer): double;
begin
  if fbFinalize then result:=faDensity[Idx] else result:=NaN;
end;

function TGTMReg.GetCoherence(Idx: integer): double;
begin
  if fbFinalize then result:=faCoherence[Idx] else result:=NaN;
end;

function TGTMReg.GetLandscape(Idx: integer): double;
begin
  if fbFinalize then result:=faLandscape[Idx] else result:=NaN;
end;

function TGTMReg.GetLandscape2(Idx: integer): double;
begin
  if fbFinalize then result:=faLandscape2[Idx] else result:=NaN;
end;

function TGTMReg.GetTrustworthiness(Idx: integer): double;
begin
  if fbFinalize then result:=faTrustworthiness[Idx] else result:=NaN;
end;

procedure TGTMReg.SetCoherence(Idx: integer; AValue: double);
begin
  if (Idx>=1) and (Idx<=High(faCoherence)) then faCoherence[Idx]:=AValue
  else
    begin
      raise Exception.Create('ERROR TGTMReg.SetCoherence: writing at position '+IntToStr(Idx)+'; authorized positions are between 1 and '+IntToStr(High(faCoherence)));
      halt;
    end;
end;

procedure TGTMReg.SetDensity(Idx: integer; AValue: double);
begin
  if (Idx>=1) and (Idx<=High(faDensity)) then faDensity[Idx]:=AValue
  else
    begin
      raise Exception.Create('ERROR TGTMReg.SetDensity: writing at position '+IntToStr(Idx)+'; authorized positions are between 1 and '+IntToStr(High(faDensity)));
      halt;
    end;
end;

procedure TGTMReg.SetLandscape(Idx: integer; AValue: double);
begin
  //writeln('Id='+IntToStr(Idx)+' High(landscape)='+IntToStr(High(faLandscape))+' aValue='+FloatToStr(avalue));
  if (Idx>=1) and (Idx<=High(faLandscape)) then faLandscape[Idx]:=AValue
  else
    begin
      Writeln('ERROR TGTMReg.SetLandscape: writing at position '+IntToStr(Idx)+'; authorized positions are between 1 and '+IntToStr(High(faLandscape)));
      halt;
    end;
end;

procedure TGTMReg.SetLandscape2(Idx: integer; AValue: double);
begin
  if (Idx>=1) and (Idx<=High(faLandscape2)) then faLandscape2[Idx]:=AValue
  else
    begin
      Writeln('ERROR TGTMReg.SetLandscape2: writing at position '+IntToStr(Idx)+'; authorized positions are between 1 and '+IntToStr(High(faLandscape2)));
      halt;
    end;
end;

procedure TGTMReg.SetTrustworthiness(Idx: integer; AValue: double);
begin
  if (Idx>=1) and (Idx<=High(faTrustworthiness)) then faTrustworthiness[Idx]:=AValue
  else
    begin
      Writeln('ERROR TGTMReg.SetTrustworthiness: writing at position '+IntToStr(Idx)+'; authorized positions are between 1 and '+IntToStr(High(faTrustworthiness)));
      halt;
    end;
end;

procedure TGTMReg.AddMolecule(sRes: string);
var
  sl1, sl2: string;
begin
  sl1:=Copy(sRes,Pos(' ',sRes),Length(sRes));//Responsability string
  sl2:=Copy(sRes,1,Pos(' ',sRes)-1);//Property string
  AddMolecule(sl1,sl2);
end;

procedure TGTMReg.AddMolecule(sRes, sPrp: string);
var
  dprp: double;
begin
  if sPrp<>'' then
  begin
    dprp := StrToFloat(sPrp);//Get the associated responsibility
    AddMolecule(sRes,dprp);
  end;
end;

procedure TGTMReg.AddMolecule(sRes: string; dPrp: double);
var
  ii,kk: integer;
  dResVal: double;
  SLRspM,SLRspN: TStringList; // String list of responsiblities of molecule
  aResMol: array of double;
begin
  SLRspM:=TStringList.Create;
  SLRspN:=TStringList.Create;
  SLRspM.Delimiter := ' ';
  SLRspM.StrictDelimiter := False;
  SLRspN.Delimiter := ':';
  SLRspN.StrictDelimiter := True;
  if (sRes <> '') then
  begin
    SLRspM.DelimitedText := sRes;
    //Check the integrity of the responsibility file
    SLRspN.DelimitedText := SLRspM.Strings[SLRspM.Count - 1];
    if (K <> 0) and (K <> StrToInt(SLRspN[0])) then
    begin
      raise Exception.Create('ERROR AddMolecule: Unexpected number of nodes in string: '
        + sRes);
      halt;
    end;
    SetLength(aResMol,K+1);
    for kk := 0 to K do
      aResMol[kk] := 0; //Reset the array of responsibilities
    for ii := 1 to SLRspM.Count - 1 do
    begin
      SLRspN.DelimitedText := SLRspM[ii];
      kk := StrToInt(SLRspN[0]);
      dResVal := StrToFloat(SLRspN[1]);
      aResMol[kk] := dResVal;
    end;
    AddMolecule(aResMol,dprp);//Add molecule to landscape
  end;
  FreeAndNil(SLRspM);
  FreeAndNil(SLRspN);
end;

procedure TGTMReg.AddMolecule(aRMol: TAoD; dprp: double);
var
  kk: integer;
  bContrib: boolean;
  dtmp: double;
begin
  Inc(fnMol0); //Count all molecules
  bContrib:=False;//A priori the molecule does not contribute
  for kk := 1 to K do
    if (aRMol[kk]>=fdMinRspToNode) then bContrib:=True;
  if bContrib = True then //Contribute only if at least one responsibility has a sufficient value
  begin
    Inc(fnMol1);//Count only contributing molecules
    //Add contribution
    fdPrpMean:=fdPrpMean+dprp;
    fdPrpStdDev:=fdPrpStdDev+sqr(dprp);
    for kk:=1 to K do
    begin
      faDensity[kk]:=faDensity[kk]+aRMol[kk];
      faLandscape[kk]:=faLandscape[kk]+dprp*aRMol[kk];
      faLandscape2[kk]:=faLandscape2[kk]+sqr(dprp)*aRMol[kk];
    end;
    //Compute the min/max of the property
    if IsNan(fdPrpMin) then fdPrpMin:=dprp;
    if IsNan(fdPrpMax) then fdPrpMax:=dprp;
    if dprp<fdPrpMin then fdPrpMin:=dprp;
    if dprp>fdPrpMax then fdPrpMax:=dprp;
  end;
end;

function TGTMReg.hmgDensity(): double;
begin
  if fbFinalize then result:=fnMol1/K else result:=NaN;
end;

function TGTMReg.minDensity(): double;
var
  kk: integer;
begin
  if fbFinalize then
  begin
    result := MaxDouble;
    for kk:=1 to K do
      if (faDensity[kk]<result) and (faDensity[kk]>0) then result:=faDensity[kk];
   end else result:=NaN;
end;

function TGTMReg.maxDensity(): double;
//var
//  kk: integer;
begin
  if fbFinalize then Result:=maxvalue(faDensity) else Result:=NaN;
{  Result:=MinDouble;
  if fbFinalize then begin
    for kk:=1 to K do
      if not IsNan(faDensity[kk]) and (Result<faDensity[kk]) then Result:=faDensity[kk];
  end else result:=NaN;}
end;

function TGTMReg.PredMol(aRes: TAoD; out dmean, dstdev, dTrst: double; out
  bInAD: boolean): double;
// In previous implementation, the prediction was accepted if the
// responsibility on at least one node was sufficient.
// It is better to request also that the responsibilities of a compound on unmapped
// region (no property value on the nodes) is limited.
const
  minRSum=0.99;
var
  kk: integer;
  dRSum, dRSumAD: double;
begin
  //Check for applicability domain
  //The compound shall be localized enough. Using the likelihood is more
  //difficult because likelihood order of magnitude are problem dependent.
  bInAD:=False;
  dRSum:=0;
  for kk:=1 to K do
  begin
    dRSum:=dRSum+aRes[kk];
    if aRes[kk]>fdMinRspToNode then bInAD:=True; //At least one responsibility shall be large enough
  end;
  if dRSum<minRSum then bInAD:=False; //Sum of responsibilities shall be close to 1. If not, the responsibilities were anomalous and the molecule is an outlier.
  // Prediction is Landscape x Responsabilities of molecule. If not in AD it is the average property value.
  result:=0;
  dRSumAD:=0;
  dmean:=0;
  dstdev:=0;
  if bInAD then
  begin
    for kk:=1 to K do
    begin
      //Nan landscape values are replaced by fdPrpMean value to compute the property
      if not IsNan(faLandscape[kk]) then
      begin
        //writeln('faTrustworthiness['+IntToStr(kk)+'='+FloatToStr(faTrustworthiness[kk])+']');
        dmean:=dmean+faLandscape[kk]*aRes[kk]*faTrustworthiness[kk]; //Property*Responsability*Trustworthiness - see doi:10.1021/acs.jcim.0c00998
      end else dmean:=dmean+fdPrpMean*aRes[kk]*faTrustworthiness[kk];
      dRSumAD:=dRSumAD+aRes[kk]*faTrustworthiness[kk]; //Trustworthiness weighted normalization factor
    end;
    dmean:=dmean/dRSumAD;
    //Compute standard dev of the prediction.
    //Variance is the sum of the variance of the estimate and the variance of the GP model
    //See Gauss–Markov theorem (Chiles & Delfiner 1999, p. 159)
    for kk:=1 to K do
      //Nan landscape values are replaced by fdPrpMean value to compute the property
      if not (IsNan(faLandscape[kk]) or IsNan(faLandscape2[kk])) then //both values shall be evaluated
        dstdev:=dstdev+sqr(faLandscape[kk]-dmean)*aRes[kk]*faTrustworthiness[kk]{+sqr(faLandscape2[kk])*aRes[kk]*faTrustworthiness[kk]}
      else dstdev:=dstdev+sqr(fdPrpMean-dmean)*aRes[kk]*faTrustworthiness[kk]{+sqr(fdPrpStdDev)*aRes[kk]*faTrustworthiness[kk]};
    dstdev:=dstdev/dRSumAD;
    if dstdev>=0 then dstdev:=sqrt(dstdev) else dstdev:=NaN;
    //Compute the trustworthiness score: (1-dstdev/PrpRng)*dRSumAD
    dTrst:=(1-dstdev/fdPrpRng);
    dTrst:=dTrst*dRSumAD;
    //If the sum of responsibilities on mapped node (with a landscape value) is insufficient
    if (dRSumAD<fdMinRspAD) or (dTrst<fdTT) then
    begin
      bInAD:=False;
      result:=fdPrpMean;
    end else result:=dmean;
  end else result:=fdPrpMean;
end;

function TGTMReg.GetDensityXYZ(): TMatrix;
var
  kk: integer;
  x,y,z: double;
  aDensityXYZ: TMatrix;
begin
  DimMatrix(aDensityXYZ,K,3);
  for kk:=1 to K do
  begin
    x:=matX[kk,1];
    y:=matX[kk,2];
    z:=faDensity[kk];
    aDensityXYZ[kk,1]:=x;
    aDensityXYZ[kk,2]:=y;
    aDensityXYZ[kk,3]:=z;
  end;
  Result:=aDensityXYZ;
end;

function TGTMReg.GetLandscapeXYZ(): TMatrix;
var
  kk: integer;
  x,y,z: double;
  aLandscapeXYZ: TMatrix;
begin
  DimMatrix(aLandscapeXYZ,K,3);
  for kk:=1 to K do
  begin
    x:=matX[kk,1];
    y:=matX[kk,2];
    z:=faLandscape[kk];
    aLandscapeXYZ[kk,1]:=x;
    aLandscapeXYZ[kk,2]:=y;
    aLandscapeXYZ[kk,3]:=z;
  end;
  Result:=aLandscapeXYZ;
end;

function TGTMReg.GetLandscape2XYZ(): TMatrix;
var
  kk: integer;
  x,y,z: double;
  aLandscape2XYZ: TMatrix;
begin
  DimMatrix(aLandscape2XYZ,K,3);
  for kk:=1 to K do
  begin
    x:=matX[kk,1];
    y:=matX[kk,2];
    z:=faLandscape2[kk];
    aLandscape2XYZ[kk,1]:=x;
    aLandscape2XYZ[kk,2]:=y;
    aLandscape2XYZ[kk,3]:=z;
  end;
  Result:=aLandscape2XYZ;
end;

procedure TGTMReg.ReadGTMModel(xmlfle: string);
var
  aGTMXML: TGTMXML;
begin
  aGTMXML:=TGTMXML.Create;
  aGTMXML.ReadGTMModel(TGTMBase(Self),xmlfle);
  DoInitialize();
  FreeAndNil(aGTMXML);
end;

procedure TGTMReg.DoInitialize();
var
  kk: integer;
begin
  DimMatX(K);
  SetLength(faDensity,K+1);
  SetLength(faLandscape,K+1);
  SetLength(faLandscape2,K+1);
  SetLength(faCoherence,K+1);
  SetLength(faTrustworthiness,K+1);
  for kk:=0 to K do
  begin
    faDensity[kk]:=0;
    faLandscape[kk]:=0;
    faLandscape2[kk]:=0;
    faCoherence[kk]:=0;
    faTrustworthiness[kk]:=0;
  end;
end;

procedure TGTMReg.DoFinalize;
var
  kk: integer;
  dSumDensity, dMaxDensity, dMaxTrustworthiness, dval: double; //Is proportional to number of molecule but shall be recomputed to decrease numerical noise
  aNDensity: TAoD;//Normalized density in [0,1]
begin
  dval:=NaN;
  //Finalize Landscape
  fdPrpMean:=fdPrpMean/fnMol1; //Compute average property value on contributing molecules
  fdPrpStdDev:=sqrt(fdPrpStdDev/fnMol1-sqr(fdPrpMean));//Compute standard dev of property on contributing molecules
  fdPrpRng:=fdPrpMax-fdPrpMin;//The range width of the proporty values
  if fdPrpRng<=0 then
  begin
    raise Exception.Create('ERROR: DoFinalize, the property range is anomalous: '+FloatToStr(fdPrpRng));
    halt(1);
  end;
  //Compute the sum of densities and the maximum density
  dSumDensity:=0;
  dMaxDensity:=MinDouble;
  for kk:=1 to K do
  begin
    dSumDensity:=dSumDensity+faDensity[kk];
    if not IsNaN(faDensity[kk]) then
      if faDensity[kk]>dMaxDensity then
        dMaxDensity:=faDensity[kk];
  end;
  //Normalize the density
  SetLength(aNDensity,High(faDensity)+1);
  for kk:=1 to K do
    aNDensity[kk]:=faDensity[kk]/dMaxDensity; //Normalized density
  //Compute the landscape and std dev density
  for kk:=1 to K do
  begin
    if (faDensity[kk]/dSumDensity >= fdMinDensityLS) and (faDensity[kk] > 0) then //Exclude empty nodes from the landscape
      faLandscape[kk]:=faLandscape[kk]/faDensity[kk]
    else faLandscape[kk]:=NaN;
  end;
  for kk:=1 to K do
  begin
    //if (faDensity[kk]/dSumDensity >= fdMinDensityLS) and (faDensity[kk] > 0) and (faLandscape2[kk]/faDensity[kk]-sqr(faLandscape[kk])>0) then //Exclude empty nodes from the landscape and undefined standard dev
    //  faLandscape2[kk]:=sqrt(faLandscape2[kk]/faDensity[kk]-sqr(faLandscape[kk])) //Carefull about a negative square root possible error
    //if (faDensity[kk]/dSumDensity >= fdMinDensityLS) and (faDensity[kk] > 0) and (faLandscape2[kk]-sqr(faLandscape[kk])>0) then //Exclude empty nodes from the landscape and undefined standard dev
    //  faLandscape2[kk]:=sqrt((faLandscape2[kk]-sqr(faLandscape[kk]))/faDensity[kk]) //Carefull about a negative square root possible error
    //if (not IsNaN(faLandscape[kk])) and ((faLandscape2[kk]/faDensity[kk]-sqr(faLandscape[kk]))<0) then
    //  writeln('Bug: '+FloatToStr(faLandscape2[kk]/faDensity[kk]-sqr(faLandscape[kk])));
    if (not IsNaN(faLandscape[kk])) then
    begin
      if ((faLandscape2[kk]/faDensity[kk]-sqr(faLandscape[kk]))>=0) then
        faLandscape2[kk]:=sqrt(faLandscape2[kk]/faDensity[kk]-sqr(faLandscape[kk]))
      else
        faLandscape2[kk]:=0;
    end else faLandscape2[kk]:=NaN;
  end;
  //Compute coherence and trustworthiness
  for kk:=1 to K do begin
    dval:=1-faLandscape2[kk]/fdPrpRng;//Coherence score = 1 - StdDev[node]/(PrpMax-PrpMin)
    if not IsNan(dval) then faCoherence[kk]:=dval
    else faCoherence[kk]:=0;
  end;
  dMaxTrustworthiness:=MinDouble;
  for kk:=1 to K do begin
    faTrustworthiness[kk]:=fdTtau+Power(aNDensity[kk],fdTalpha)*Power(faCoherence[kk],fdTbeta); //Coherence score = tau + NormalizedDensity^alpha*Coherence^beta
    if dMaxTrustworthiness<faTrustworthiness[kk] then dMaxTrustworthiness:=faTrustworthiness[kk];
  end;
  for kk:=1 to K do
    faTrustworthiness[kk]:=faTrustworthiness[kk]/dMaxTrustworthiness;
  //writeln;
  //for kk:=1 to K do writeln('faTrustworthiness['+IntToStr(kk)+']='+FloatToStr(faTrustworthiness[kk]));
  //writeln;
  fbFinalize:=True;
end;

constructor TGTMReg.Create;
begin
  inherited Create;
  //fMinRspLS:=0;
  faDensity:=nil;
  faLandscape:=nil;
  faLandscape2:=nil;
  faCoherence:=nil;
  faTrustworthiness:=nil;
  fnMol0:=0;
  fnMol1:=0;
  fdMinRspAD:=0;
  fdMinRspToNode:=0;
  fdMinDensityLS:=0;
  fdPrpMean:=0;
  fdPrpStdDev:=0;
  fdPrpMin:=NaN;
  fdPrpMax:=NaN;
  fdPrpRng:=NaN;
  fbFinalize:=False;
  fPrpName:='default';
  fdTtau:=0.01;
  fdTalpha:=0.1;
  fdTbeta:=1.0;
  fdTT:=0.7;
end;

destructor TGTMReg.Destroy;
begin
  inherited Destroy;
end;

end.

