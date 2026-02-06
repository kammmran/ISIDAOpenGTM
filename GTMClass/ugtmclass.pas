unit UGTMClass;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, strutils, UGTMBase, UGTMXML, ulinalg, utypes, math;

const
  cOutOfAD='OutOfAD';

type
TAoD = array of double;
TAoAoD= array of array of double;

{ TGTMClass }

TGTMClass = class(TGTMBase)
private
  fClassSL: TStringList;//List of classes and population of each class
  faDensity: TVector; //density
  faLandscape: TMatrix; //landscape
  fPci: TVector; //Priors of each class
  fP_xk_ci: TMatrix; //P_xk_ci[classID,nodeID]=Pvalue. Safe resize of the table if working with many classes. Probability on node k given class i
  fP_ci_xk: TMatrix; //P_ci_xk[classID,nodeID]=Pvalue. Safe resize of the table if working with many classes. Probability of class i given node k
  fnMol0, fnMol1: integer; //# of all molecule, # of molecules contributing to landscape
  fdMinRspToNode: double; //Minimum responsibility to contribute to a node / Min responsability value to be in applicability domain
  fdMinDensityLS: double; //Minimum density value for a node to be inside, between 0 and 1 / Min responsability value to count for landscape
  fbFinalize: boolean;//Density and landscape are ready or not
  fbClassNormalize: boolean; //Balancing the classes?
  fPrpName: shortstring; //Short name for the property (max 255 char)
  frClsThrd: double; // Applicability domain based on class significance
  function GetDensity(Idx: integer): double;
  function GetLandscape(ICls,Idx: integer): double;
  function GetnClass(): integer;
  procedure SetDensity(Idx: integer; AValue: double);
  procedure SetLandscape(ICls,Idx: integer; AValue: double);

public
  property classSL: TStringList read fclassSL write fclassSL;
  //property MinRspAD: double read fMinRspAD write fMinRspAD;
  //property MinRspLS: double read fMinRspLS write fMinRspLS;
  property Density[Idx: integer]: double read GetDensity write SetDensity;
  property Landscape[ICls,Idx: integer]: double read GetLandscape write SetLandscape;
  property Pci: Tvector read fPci;
  property P_xk_ci: TMatrix read fP_xk_ci;
  property P_ci_xk: TMatrix read fP_ci_xk;
  property MinRspToNode: double read fdMinRspToNode write fdMinRspToNode;
  property MinDensityLS: double read fdMinDensityLS write fdMinDensityLS;
  property bClassNormalize: boolean read fbClassNormalize write fbClassNormalize;
  property PrpName: ShortString read fPrpName write fPrpName;
  property nMol0: integer read fnMol0;
  property nMol1: integer read fnMol1;
  property nClass: integer read GetnClass;
  property rClsThrd: double read frClsThrd write frClsThrd;
  function AddToClassSL(s: string): integer;
  procedure AddMolecule(sRes: string; out ClsIdx: Integer);//update density and landscape with responsibilities of a molecule and a class ID
  procedure AddMolecule(aRMol: TVector; ClsStr: string; out ClsIdx: Integer);//update density and landscape with responsibilities of a molecule and a class ID
  procedure PredMol(aRes: TVector; out PredCls: TVector; out bInAD: boolean);
  procedure ClearClassSL();
  procedure SetSizePrMatrix(nCls: integer);
  function hmgDensity(): double; //Homogeneous density
  function minDensity(): double; //minimal density value
  function maxDensity(): double; //maximal density value
  function GetDensityXYZ(): TMatrix;
  function GetLandscapeXYZ(): TMatrix;
  procedure ReadGTMModel(xmlfle: string);
  procedure SetMolCountToZero();
  procedure DoInitialize(); //Initialize the GTMReg using ancestor information
  procedure DoFinalize;
  property bFinalize: boolean write fbFinalize;//To set manually
  constructor Create;
  destructor Destroy; override;
end;

implementation

{ TGTMClass }

function TGTMClass.GetDensity(Idx: integer): double;
begin
  if fbFinalize then result:=faDensity[Idx] else result:=NaN;
end;

function TGTMClass.GetLandscape(ICls, Idx: integer): double;
begin
  if fbFinalize then result:=faLandscape[ICls,Idx] else result:=NaN;
end;

function TGTMClass.GetnClass(): integer;
begin
  Result:=fClassSL.Count-1;
end;

procedure TGTMClass.SetDensity(Idx: integer; AValue: double);
begin
  if (Idx>=1) and (Idx<=High(faDensity)) then faDensity[Idx]:=AValue
  else
    begin
      Writeln('ERROR TGTMClass.SetDensity: writing at position '+IntToStr(Idx)+'; authorized positions are between 1 and '+IntToStr(High(faDensity)));
      halt;
    end;
end;

procedure TGTMClass.SetLandscape(ICls, Idx: integer; AValue: double);
var
  bError: boolean;

begin
  bError:=False;
  if (ICls>=1) and (Idx<=High(faLandscape)) then
  begin
    if (Idx>=1) and (Idx<=High(faLandscape[ICls])) then
      faLandscape[ICls,Idx]:=AValue
    else
      bError:=True;
  end else bError:=True;
  if bError then
    begin
      Writeln('ERROR TGTMClass.SetLandscape: writing at position '+IntToStr(ICls)+'\'+IntToStr(Idx)+'; authorized positions are between 1 and '+IntToStr(High(faLandscape))+'\'+IntToStr(High(faLandscape[0])));
      halt;
    end;
end;

function TGTMClass.AddToClassSL(s: string): integer;
//Keep track of the class and the population of the class and return position in classSL
var
  Id: integer;
  ptI: PInteger;
begin
  Id:=fclassSL.IndexOf(s);
  if (Id<0) then
  begin
     new(ptI);
     ptI^:=0;
     Id:=fclassSL.AddObject(s,TObject(ptI));
  end;
  //
  ptI:=PInteger(fclassSL.Objects[Id]);
  ptI^:=ptI^+1;
  // If too many classes, add space for 10 additional ones
  If Id>High(fP_xk_ci) then
  begin
    SetLength(fPci,Length(fPci)+10);
    SetLength(fP_xk_ci,Length(fP_xk_ci)+10,K+1);
    SetLength(fP_ci_xk,Length(fP_xk_ci)+10,K+1);
  end;
  //
  Result:=Id;
end;

procedure TGTMClass.AddMolecule(sRes: string; out ClsIdx: Integer);
var
  ii,kk: integer; //counters
  bContrib: boolean; // monitor if in or out of AD
  vRes: TVector; // vector of responsibilities
  SLRes: TStringList; // Stringlist of responsibilities
  s1,s2: string; //dummy strings
  ClsStr: string; // string representig the class of the object
  dRes: double; // a responsibility value
begin
  Inc(fnMol0); //Count all molecules
  DimVector(vRes,K);
  //Init the responsibility string, class in first column
  SLRes:=TStringList.Create;
  SLRes.Delimiter:=' ';
  SLRes.DelimitedText:=sRes;
  bContrib:=False;//A priori the molecule does not contribute
  //
  ClsStr:=SLRes[0];
  for ii:=1 to SLRes.Count-1 do
  begin
    s1:=ExtractDelimited(1,SLRes[ii],[':']);
    s2:=ExtractDelimited(2,SLRes[ii],[':']);
    kk:=StrToInt(s1);
    dRes:=StrToFloat(s2);
    //
    if (dRes>=fdMinRspToNode) then bContrib:=True;
    vRes[kk]:=dRes;
  end;
  //
  if bContrib = True then //Contribute only if at least one responsibility has a sufficient value
  begin
    Inc(fnMol1);//Count only contributing molecules
    //Add class
    ClsIdx:=AddToClassSL(ClsStr);
    //Add contribution
    for kk:=1 to K do
    begin
      faDensity[kk]:=faDensity[kk]+vRes[kk];
      fP_xk_ci[ClsIdx,kk]:=fP_xk_ci[ClsIdx,kk]+vRes[kk];
    end;
  end else
    ClsIdx:=AddToClassSL(cOutOfAD);
  FreeAndNil(SLRes);
end;

procedure TGTMClass.ClearClassSL();
//Clear the classSL content, be sure that the population are properly disposed
var
  i: integer;
  pI: PInteger;
begin
  for i:=0 to fclassSL.Count-1 do
  begin
     pI:=PInteger(fclassSL.Objects[i]);
     if pI<>nil then begin
       Dispose(pI);
       pI:=nil;
     end;
  end;
  fclassSL.Clear;
end;

procedure TGTMClass.SetSizePrMatrix(nCls: integer);
begin
  DimVector(fPci,nCls);
  DimMatrix(fP_ci_xk,nCls,K);
  DimMatrix(fP_xk_ci,nCls,K);
end;

procedure TGTMClass.AddMolecule(aRMol: TVector; ClsStr: string; out ClsIdx: Integer);
var
  kk: integer;
  bContrib: boolean;
begin
  Inc(fnMol0); //Count all molecules
  bContrib:=False;//A priori the molecule does not contribute
  kk:=1;
  while (kk<=K) and not bContrib do
  begin
     if (aRMol[kk]>=fdMinRspToNode) then bContrib:=True;
     Inc(kk);
  end;
  if bContrib = True then //Contribute only if at least one responsibility has a sufficient value
  begin
    Inc(fnMol1);//Count only contributing molecules
    //Add class
    ClsIdx:=AddToClassSL(ClsStr);
    //Add contribution
    for kk:=1 to K do
    begin
      faDensity[kk]:=faDensity[kk]+aRMol[kk];
      fP_xk_ci[ClsIdx,kk]:=fP_xk_ci[ClsIdx,kk]+aRMol[kk];
    end;
  end else
    ClsIdx:=AddToClassSL(cOutOfAD);
end;

function TGTMClass.hmgDensity(): double;
begin
  begin
    if fbFinalize then result:=fnMol1/K else result:=NaN;
  end;
end;

function TGTMClass.minDensity(): double;
var
  i: integer;
begin
  if fbFinalize then
  begin
    result:=faDensity[1];
    for i:=1 to K do
      if ((result>faDensity[i]) and (faDensity[i]<>0)) or ((result=0) and (faDensity[i]<>0)) then
         result:=faDensity[i];
  end else result:=NaN;
end;

function TGTMClass.maxDensity(): double;
var
  i: integer;
begin
  if fbFinalize then
  begin
    result:=faDensity[1];
    for i:=1 to K do
      if ((result<faDensity[i]) and (faDensity[i]<>0)) then
         result:=faDensity[i];
  end else result:=NaN;
end;

procedure TGTMClass.PredMol(aRes: TVector; out PredCls: TVector; out bInAD: boolean); //Probability of class if P_ci_xk*Responsibility on node k; Check AD
var
  index1, index2: integer;
  Nrm: double;
  maxPred: double;
  i,imaxPred: integer;
  rprd:double;
  cc:integer;
begin
  Nrm:=0;
  bInAD:=False;
  index2:=1;
  Inc(fnMol0);
  while (index2<=K) and (bInAD=False) do
  begin
      if aRes[index2]>MinRspToNode then
        bInAD:=True;
      Inc(index2);
  end;
  DimVector(PredCls,ClassSL.Count-1);
  if bInAD then
  begin
    for index1:=0 to ClassSL.Count-1 do {run through the classes}
    begin
      PredCls[index1]:=0.0;
      for index2:=1 to K do {run through the nodes}
        PredCls[index1]:=PredCls[index1]+(P_ci_xk[index1,index2]*aRes[index2]);
    end;
    //Re-normalize the results
    Nrm:=0;
    for index1:=0 to ClassSL.Count-1 do {run through the classes}
      Nrm:=Nrm+PredCls[index1];
    if(Nrm>0) then
      for index1:=0 to ClassSL.Count-1 do
        PredCls[index1]:=PredCls[index1]/Nrm;
  end else PredCls[0]:=1; //All other values are 0 by default
  //Check if OutOfAD is dominating
  imaxPred:=0;
  maxPred:=PredCls[imaxPred];
  for i:=0 to nClass do
  begin
    if PredCls[i]>maxPred then
    begin
      maxPred:=PredCls[i];
      imaxPred:=i;
    end;
  end;
  //
  rprd:=NaN;
  if imaxPred>0 then //if not out of AD test if major class is significant
  begin
    for cc:=1 to nClass do
    begin
      if (cc<>imaxPred) then rprd:=PredCls[cc]/maxPred;//Can be NaN
      if not IsNan(rprd) then
        if (rprd>=frClsThrd) then //ambiguous class prediction -> out of AD
        begin
          imaxPred:=0;//Put to out of AD class
        end;
    end;
  end;
  //
  if (imaxPred>0) and bInAD then Inc(fnMol1);
end;

function TGTMClass.GetDensityXYZ(): TMatrix;
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

function TGTMClass.GetLandscapeXYZ(): TMatrix;
//Outputs NaN if probabilities are 0.
var
  kk, ll: integer;
  x,y,z: double;
  aLandscapeXYZ: TMatrix;
  nCls: integer;
begin
  nCls:=fclassSL.Count-1;
  DimMatrix(aLandscapeXYZ,K,2+nCls+1);//Last column for out of AD
  for kk:=1 to K do
  begin
    x:=matX[kk,1];
    y:=matX[kk,2];
    aLandscapeXYZ[kk,1]:=x;
    aLandscapeXYZ[kk,2]:=y;
    for ll:=1 to nCls do
    if fP_ci_xk[ll,kk]>0 then
      aLandscapeXYZ[kk,2+ll]:=fP_ci_xk[ll,kk]
    else aLandscapeXYZ[kk,2+ll]:=NaN;
    if fP_ci_xk[0,kk]>0 then
      aLandscapeXYZ[kk,2+nCls+1]:=fP_ci_xk[0,kk]
    else aLandscapeXYZ[kk,2+nCls+1]:=NaN;
  end;
  Result:=aLandscapeXYZ;
end;

procedure TGTMClass.ReadGTMModel(xmlfle: string);
var
  aGTMXML: TGTMXML;
begin
  aGTMXML:=TGTMXML.Create;
  aGTMXML.ReadGTMModel(TGTMBase(Self),xmlfle);
  DoInitialize();
  FreeAndNil(aGTMXML);
end;

procedure TGTMClass.SetMolCountToZero;
begin
  fnMol0:=0;
  fnMol1:=0;
end;

procedure TGTMClass.DoInitialize();
var
  kk,ll: integer;
begin
  SetMolCountToZero;
  DimMatX(K); // Set the GTM sample size
  DimVector(faDensity,K);
  for kk:=0 to K do
    faDensity[kk]:=0;
  DimMatrix(fP_ci_xk,10,K);//Prepare room for 10 classes, increase at runtime if needed
  DimMatrix(fP_xk_ci,10,K);
  DimVector(fPci,10);
  for ll:=0 to 10 do
  begin
    fPci[ll]:=0;
    for kk:=0 to K do
    begin
      fP_xk_ci[ll,kk]:=0;
      fP_ci_xk[ll,kk]:=0;
    end;
  end;
  fbClassNormalize:=False;
end;

procedure TGTMClass.DoFinalize;
var
  i,j: integer;
  ptI: PInteger;
  Pop: Integer;
  Pnorm, Psum, weight: double;
  nCls: integer;
begin
  nCls:=fclassSL.Count-1;
  // Estimate density
  for j:=1 to K do
  begin
      faDensity[j]:=faDensity[j]/nMol1;
  end;
  for i:=0 to nCls do
  begin
    ptI:=PInteger(fclassSL.Objects[i]); //Population of the class i
    fPci[i] := (ptI^+1)/(nMol1 + fclassSL.Count); //Laplace correction
    for j:=1 to K do {run through the nodes}
    begin
      fP_xk_ci[i,j]:=(fP_xk_ci[i,j]+1/K)/(ptI^+1); //Laplace correction kindof...
//      if (fP_xk_ci[i,j]< fdMinDensityLS) or (ptI^=0) then fP_xk_ci[i,j]:=0
//        else fP_xk_ci[i,j]:=fP_xk_ci[i,j]/ptI^;
     end;
  end;
//
  for i:=0 to nCls do//Renoralize to compensate of numerical imprecision
  begin
    Pnorm:=0;
    for j:=1 to K do
      Pnorm:=Pnorm+fP_xk_ci[i,j];
    for j:=1 to K do
//      if Pnorm > 1E-11 then //use MachEp instead? (machine precision)
        fP_xk_ci[i,j]:=fP_xk_ci[i,j]/Pnorm
//      else
//        fP_xk_ci[i,j]:=0;
  end;
  { calculating P(ci|xk) for each class and for each node; Normalize on classes }
  for i:=0 to nCls do {run through the classes}
    for j:=1 to K do {run through the nodes}
      fP_ci_xk[i,j]:= (fP_xk_ci[i,j]*fPci[i]);//Some values are Nan
      {if faDensity[j]>1E-11 then
        fP_ci_xk[i,j]:= (fP_xk_ci[i,j]*fPci[i])
      else begin
        if i=0 then // Count as Out of AD
          fP_ci_xk[i,j]:= 1.0  //
        else                   //
          fP_ci_xk[i,j]:= 0.0; //
      end;}
  for j:=1 to K do {run through the nodes}
  begin
    PNorm:=0;
    if faDensity[j]>1E-11 then
    begin
      for i:=0 to nCls do {run through the classes}
        PNorm:=PNorm+fP_ci_xk[i,j];
      for i:=0 to nCls do {run through the classes}
        fP_ci_xk[i,j]:=fP_ci_xk[i,j]/PNorm;
    end else
    begin //No density -> OutOfAD
      for i:=1 to nCls do fP_ci_xk[i,j]:=0;
      fP_ci_xk[0,j]:=1;
    end;
      {if PNorm>1E-11 then
        fP_ci_xk[i,j]:=fP_ci_xk[i,j]/PNorm
      else
        fP_ci_xk[i,j]:= 0.0;}
  end;
  { Bayes Reweighting }
  if fbClassNormalize=true then
  begin
     Psum:=0; // Compute weight = (N/N(Ci))/(Sum_i N/N(Ci))
     for i:=1 to nCls do {run through the classes, ignore OutOfAD class}
     begin
       Pop:=PInteger(classSL.Objects[i])^;
       if (Pop>0) then Psum:=Psum+1/Pop;
       //Psum := Psum + 1/fPci[i];
     end;
     PSum:=PSum*nMol1;
     If Psum>0 then
     begin
       for i:=1 to nCls do {run through the classes, ignore OutOfAD}
       begin
          Pop:=PInteger(classSL.Objects[i])^;
          if Pop>0 then weight:=(nMol1/Pop)/Psum else weight:=0;
          //weight:=(1/fPci[i])/Psum;
          //writeln(Pop,weight,Pop*weight);
          for j:=1 to K do {run through the nodes}
            fP_ci_xk[i,j] := weight*fP_ci_xk[i,j];
       end;
       //Renormalize for OutOfAD
       for i:=0 to nCls do {run through the classes}
       begin
          PSum:=0;
          for j:=1 to K do
            PSum:=PSum+fP_ci_xk[i,j];
          for j:=1 to K do
            if PSum>0 then fP_ci_xk[i,j]:=fP_ci_xk[i,j]/PSum else fP_ci_xk[i,j]:=0;
       end;
       //Homogeneize the priors, ignoring OutOfAD
       for i:=1 to nCls do fPci[i]:=1/nCls;
       //Renormalize
       PSum:=0;
       for i:=0 to nCls do PSum:=PSum+fPCi[i];
       for i:=0 to nCls do fPCi[i]:=fPci[i]/Psum;
     end;
  end;
  fbFinalize:=True;
end;

constructor TGTMClass.Create;
var
  ptI: PInteger;
begin
  inherited Create;
  fClassSL:=TStringList.Create;
  //Class ID 0 is OutOfAD
  new(ptI);
  ptI^:=0;
  classSL.AddObject(cOutOfAD,TObject(ptI));
  //
  faDensity:=nil;
  faLandscape:=nil;
  fPci:=nil;
  fP_xk_ci:=nil;
  fP_ci_xk:=nil;
  fnMol0:=0;
  fnMol1:=0;
  fdMinRspToNode:=0;
  fdMinDensityLS:=0;
  fbClassNormalize:=False;
  fbFinalize:=False;
  fPrpName:='default';
  frClsThrd:=1;
end;

destructor TGTMClass.Destroy;
begin
  ClearClassSL();
  FreeAndNil(fClassSL);
  inherited Destroy;
end;

end.

