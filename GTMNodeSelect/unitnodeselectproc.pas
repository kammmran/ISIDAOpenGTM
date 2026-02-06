unit UnitNodeSelectProc;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,
  Contnrs,math,streamex,utypes,ulinalg,UGTMBase,UGTMFull,UGTMSparse, UcGTM,
  UGTMXML,XMLRead, XMLWrite, DOM, UnitLLStringList, Forms;

procedure LoadSDF(const sSDF: string; OLSDF: TObjectList);
procedure WriteSDF(const sSDF: string; const OLSDF: TObjectList);
procedure RestrictedLikelyhood(SLmols: TLLStringList; acGTM: TcGTM; thrld: Double; out XT: TMatrix; LLt, LLtmin: Double; SLtmp:TStringList; SLlog: TStringList);
procedure RestrictedLikelyhood(SLmols: TLLStringList; acGTM: TcGTM; thrld: Double; out LLt, LLtmin: Double; SLlog: TStringList);
procedure PopThrldToMxRThrld(SLmols: TLLStringList; const aN: integer; const MxR: TVector; const thrld: double; var MxRthrld: double);
procedure FilterByLikelyhood(const acGTM: TcGTM; const LLtmin: double; var aSL: TStringList);
procedure FilterByLikelyhood(const acGTM: TcGTM; const LLtmin: double; var aOL: TObjectList);
procedure FilterByLikelyhood(const acGTM: TcGTM; const LLtmin: double; var XT: TMatrix);
procedure FilterByRMx(const MxR: TVector; const NMxR: integer; const MxRmin: double; var aSL: TStringList);
procedure FilterByRMx(const MxR: TVector; const NMxR: integer; const MxRmin: double; var aOL: TObjectList);
procedure FilterByRMx(const MxR: TVector; const NMxR: integer; acGTM: TcGTM; const MxRmin: double; var XT: TMatrix);
procedure GeneratedFromSelected(acGTM: TcGTM; ngenerate: integer; out aSmpleX, aSmpleZ: TMatrix);
procedure DoZoomOnGTM(acGTM,zcGTM:TcGTM; xmax,xmin,ymax,ymin: double; XT: TMatrix; SLlog: TStringList; const MaxIter: integer=0; const convCriteria: double=0.01);
procedure ProjectOnZoom(zcGTM:TcGTM; SLlog: TStringList; XT: TMatrix; const MaxIter: integer=0; const convCriteria: double=0.01);
procedure ProjectOnZoom(zcGTM:TcGTM; SLlog: TStringList; const MaxIter: integer=0; const convCriteria: double=0.01);
function ProjectData(myGTM: TGTMFull; TZ: TMatrix; Nmax: integer; b3D: boolean; s3Dfile: string): double;
function ProjectDataOnSelected(myGTM: TcGTM; TZ: TMatrix; Nmax: integer; var LLt: double; b3D: boolean; s3Dfile: string): double;
function ProjectDataFomManifold(myGTM: TcGTM; TZ: TMatrix; Nmax: integer; var LLt: double; b3D: boolean; s3Dfile: string): double;

implementation

procedure LoadSDF(const sSDF: string; OLSDF: TObjectList);
// Load and SDF file in a TObjectList, one molecules in SDF format per item
var
  aFR: TFileReader;
  aSDF: TStringList;
  aline: string;
begin
  aFR:=TFileReader.Create(sSDF);
  OLSDF.Add(TStringList.Create);
  aSDF:=OLSDF.Last as TStringList;
  aline:='';
  while(not aFR.Eof) do
  begin
    aline:=aFR.ReadLine;
    aSDF.Add(aline);
    if (aline='$$$$') and (not aFR.Eof) then
    begin
       OLSDF.Add(TStringList.Create);
       aSDF:=OLSDF.Last as TStringList;
    end;
  end;
  FreeAndNil(aFR);
end;

procedure WriteSDF(const sSDF: string; const OLSDF: TObjectList);
var
  i: integer;
  aSDF: TStringList;
  aFStr: TFileStream;
begin
  aFStr:=TFileStream.Create(sSDF,fmCreate);
  for i:=0 to OLSDF.Count-1 do
  begin
    aSDF:=OLSDF[i] as TStringList;
    aSDF.SaveToStream(aFStr);
  end;
  FreeAndNil(aFStr);
end;

procedure RestrictedLikelyhood(SLmols: TLLStringList; acGTM: TcGTM;
  thrld: Double; out XT: TMatrix; LLt, LLtmin: Double; SLtmp: TStringList;
  SLlog: TStringList);
//Compute the likelyhood of selected input molecules based on the restricted manifold
//SLmols: String list of the input molecules to project
//acGTM: the restricted manifold
//thrld: the percentage of molecules to keep based on the likelyhood
//LLt: the likelyhood of the dataset
//LLtmin: the minimal likelyhood after filtering
//SLlog: records log messages
var
  ii,id,ii1: integer;
  sdata: string;
begin
  SLtmp.Clear;
  for ii:=0 to SLmols.Count-1 do // deep copy of SLmols into SLtmp
    SLtmp.Add(SLmols.Strings[ii]);
  acGTM.Init;
  acGTM.Project(True,True,True,True); // Here the manifold is already set and projection can be done on selected nodes
  LLt:=acGTM.LogLikelyHoodOnSelected();
  SLlog.Add('Restricted Loglikelihood - all molecules: '+FloatToStr(LLt));
  //Sort molecules according to their log likelihood and save the results in the file *_Sorted.svm
  for ii:=1 to acGTM.N do
  begin
    SLmols.Objects[ii-1]:=TObject(@acGTM.LLM[ii]);
  end;
  SLmols.Direction:=aDown;//sort by decreasing order
  SLmols.LLSort();
  for ii:=SLmols.Count-1 downto ceil(acGTM.N*thrld) do SLmols.Delete(ii);//Keep the top thrld first instances
  LLtmin:=PDouble(SLmols.Objects[SLmols.Count-1])^; //This definese the minimal likelihood
  //Output the selected molecules according to restricted likelihood
  LLt:=PDouble(SLmols.Objects[0])^;
  for ii:=1 to SLmols.Count-1 do
  begin
    LLt:=LLt+PDouble(SLmols.Objects[ii])^;
  end;
  LLt:=LLt/SLmols.Count;
  SLlog.Add('Restricted Likelihood - '+IntToStr(SLmols.Count)+' selected data: '+FloatToStr(LLt));
  //Prepare the coordinates of selected compounds to be projected on the selected submanifold
  DimMatrix(XT,SLmols.Count,acGTM.D);
  ii1:=1;
  sdata:=' '; // <- To remove for speed or large datasets
  for ii:=1 to acGTM.N do//Copy from acGTM to keep original relative order of the instances
    if (acGTM.LLM[ii]>=LLtmin) and (ii1<=High(XT)) then
    begin
      for id:=1 to acGTM.D do
        XT[ii1,id]:=acGTM.X[ii,id];
      Inc(ii1);
      sdata:=sdata+IntToStr(ii)+' '; // <- To remove for speed or large datasets
    end;
  SLlog.Add('selected data : ('+sdata+')'); // <- To remove for speed or large datasets
  //
  for ii:=SLtmp.Count-1 downto 0 do// SLtmp contains a copy of the data in their initial order. They are filtered the same way to preserve the original order of the instances
    if (acGTM.LLM[ii+1]<LLtmin) then
       SLtmp.Delete(ii);
end;

procedure RestrictedLikelyhood(SLmols: TLLStringList; acGTM: TcGTM;
  thrld: Double; out LLt, LLtmin: Double; SLlog: TStringList);
//Compute the likelyhood of selected input molecules based on the restricted manifold - new data files are NOT prepared
//SLmols: String list of the input molecules to project
//acGTM: the restricted manifold
//thrld: the percentage of molecules to keep based on the likelyhood
//LLt: the likelyhood of the dataset
//LLtmin: the minimal likelyhood after filtering
//SLlog: records log messages
var
  ii,id,ii1: integer;
  sdata: string;
begin
  acGTM.Init;
  acGTM.Project(True,True,True,True); // Here the manifold is already set and projection can be done on selected nodes
  LLt:=acGTM.LogLikelyHoodOnSelected();
  SLlog.Add('Restricted Loglikelihood - all molecules: '+FloatToStr(LLt));
  //Sort molecules according to their log likelihood and save the results in the file *_Sorted.svm
  for ii:=1 to acGTM.N do
  begin
    SLmols.Objects[ii-1]:=TObject(@acGTM.LLM[ii]);
  end;
  SLmols.Direction:=aDown;//sort by decreasing order
  SLmols.LLSort();
  for ii:=SLmols.Count-1 downto ceil(acGTM.N*thrld) do SLmols.Delete(ii);//Keep the top thrld first instances
  LLtmin:=PDouble(SLmols.Objects[SLmols.Count-1])^; //This definese the minimal likelihood
  //Output the selected molecules according to restricted likelihood
  LLt:=PDouble(SLmols.Objects[0])^;
  for ii:=1 to SLmols.Count-1 do
  begin
    LLt:=LLt+PDouble(SLmols.Objects[ii])^;
  end;
  LLt:=LLt/SLmols.Count;
  SLlog.Add('Restricted Likelihood - '+IntToStr(SLmols.Count)+' selected data: '+FloatToStr(LLt));
end;

procedure PopThrldToMxRThrld(SLmols: TLLStringList; const aN: integer;
  const MxR: TVector; const thrld: double; var MxRthrld: double);
//Prepare the list of molecules according to their max. responsibility and defines the threshold based on the max responsibility
//SLmols: String list of the input molecules to project
//aN: the size of the dataset
//MxR: the corresponding vector of max responsibilities - 0 if the max is out of the selected nodes
//Mxthrld: the percentage of molecules to keep based on the likelyhood
//LLt: the likelyhood of the dataset
//LLtmin: the minimal likelyhood after filtering
//SLlog: records log messages
var
  ii,id,iimax: integer;
  sdata: string;
  v:double;
begin
  //Sort molecules according to their log likelihood and save the results in the file *_Sorted.svm
  for ii:=1 to aN do
  begin
    SLmols.Objects[ii-1]:=TObject(@MxR[ii]);
  end;
  SLmols.Direction:=aDown;//sort by decreasing order
  SLmols.LLSort();
  for ii:=SLmols.Count-1 downto 0 do
    if PDouble(SLmols.Objects[ii])^=0 then SLmols.Delete(ii);
  iimax:=SLmols.Count-1;
  for ii:=SLmols.Count-1 downto ceil(iimax*thrld) do SLmols.Delete(ii);//Keep the top thrld first instances
  MxRthrld:=PDouble(SLmols.Objects[SLmols.Count-1])^; //This definese the minimal max. responsibility
end;

procedure FilterByLikelyhood(const acGTM: TcGTM; const LLtmin: double;
  var aSL: TStringList);
var
  ii: integer;
begin
  if (acGTM.N=aSL.Count-1) then
    for ii:=aSL.Count-1 downto 1 do// aSL shall contain the same number of lines than the number of instances currently in the GTM plus a title line
      if (acGTM.LLM[ii]<LLtmin) then
      begin
        aSL.Delete(ii);
      end;
end;

procedure FilterByLikelyhood(const acGTM: TcGTM; const LLtmin: double;
  var aOL: TObjectList);
var
  ii: integer;
begin
  if (acGTM.N=aOL.Count) then
    for ii:=aOL.Count-1 downto 0 do// aOL shall contain the same number of items than the number of instances currently in the GTM
      if (acGTM.LLM[ii+1]<LLtmin) then
         aOL.Delete(ii);
end;

procedure FilterByLikelyhood(const acGTM: TcGTM; const LLtmin: double;
  var XT: TMatrix);
var
  N, id,ii,ii1: Integer;
begin
  N:=0; // Compute the number of selected data
  for ii:=1 to acGTM.N do//Copy from acGTM to keep original relative order of the instances
    if (acGTM.LLM[ii]>=LLtmin) then
       Inc(N);
  //Prepare the coordinates of selected compounds to be projected on the selected submanifold
  DimMatrix(XT,N,acGTM.D);
  ii1:=1;
  for ii:=1 to acGTM.N do//Copy from acGTM to keep original relative order of the instances
    if (acGTM.LLM[ii]>=LLtmin) then
    begin
      for id:=1 to acGTM.D do
        XT[ii1,id]:=acGTM.X[ii,id];
      Inc(ii1);
    end;
end;

{procedure FilterByRMx(const acGTM: TcGTM; const MxRmin: double;
  var aSL: TStringList);
var
  ii: integer;
begin
  if (acGTM.N=aSL.Count-1) then
    for ii:=aSL.Count-1 downto 1 do// aSL shall contain the same number of lines than the number of instances currently in the GTM plus a title line
      if (acGTM.MxR(ii)<MxRmin) then
      begin
        aSL.Delete(ii);
      end;
end;

procedure FilterByRMx(const acGTM: TcGTM; const MxRmin: double;
  var aOL: TObjectList);
var
  ii: integer;
begin
  if (acGTM.N=aOL.Count) then
    for ii:=aOL.Count-1 downto 0 do// aOL shall contain the same number of items than the number of instances currently in the GTM
      if (acGTM.MxR(ii+1)<MxRmin) then
         aOL.Delete(ii);
end;}

procedure FilterByRMx(const MxR: TVector; const NMxR: integer;
  const MxRmin: double; var aSL: TStringList);
var
  ii: integer;
begin
  if (NMxR=aSL.Count) then
    for ii:=aSL.Count-1 downto 0 do// aSL shall contain the same number of lines than the number of instances currently in the GTM
      if (MxR[ii+1]<=MxRmin) then
      begin
        aSL.Delete(ii);
      end;
end;

procedure FilterByRMx(const MxR: TVector; const NMxR: integer;
  const MxRmin: double; var aOL: TObjectList);
var
  ii{,ii1}: integer;
  //stmp: string;
begin
  //ii1:=0 ;
  if (NMxR=aOL.Count) then
    for ii:=aOL.Count-1 downto 0 do// aOL shall contain the same number of items than the number of instances currently in the GTM
      if (MxR[ii+1]<=MxRmin) then
      begin
         aOL.Delete(ii);
      end;{ else begin
         Inc(ii1);
      end;}
  //stmp:=IntToStr(ii1)+' '+IntToStr(aOL.Count);
end;

procedure FilterByRMx(const MxR: TVector; const NMxR: integer; acGTM: TcGTM;
  const MxRmin: double; var XT: TMatrix);
var
  N, id,ii,ii1: Integer;
begin
  N:=0; // Compute the number of selected data
  for ii:=1 to NMxR do//MxR keeps original relative order of the instances
    if (MxR[ii]>MxRmin) then
       Inc(N);
  //Prepare the coordinates of selected compounds to be projected on the selected submanifold
  DimMatrix(XT,N,acGTM.D);
  ii1:=1;
  for ii:=1 to NMxR do//Copy from acGTM to keep original relative order of the instances
    if (MxR[ii]>MxRmin) then
    begin
      for id:=1 to acGTM.D do
        XT[ii1,id]:=acGTM.X[ii,id];
      Inc(ii1);
    end;
end;

procedure GeneratedFromSelected(acGTM: TcGTM; ngenerate: integer; out aSmpleX, aSmpleZ: TMatrix);
//Generate data from the selected nodes in the GTM.
//acGTM: the manifold to sample from
//ngenerate: the size of the sample
//aSampleX: the sampled data in the manifold plane
//aSampleZ: the sampled data in the initial data space
begin
  acGTM.Init();
  acGTM.UpdateMatY(False);//Compute the manifold coordinates for all nodes
  acGTM.Generate(ngenerate,aSmpleZ,aSmpleX);
end;

procedure DoZoomOnGTM(acGTM, zcGTM: TcGTM; xmax, xmin, ymax, ymin: double;
  XT: TMatrix; SLlog: TStringList; const MaxIter: integer;
  const convCriteria: double);
//Compute a zoom on a selected nodes
//acGTM: the GTM to zoom on
//zcGTM: the zoomed GTM
//xmax, xmin, ymax, ymin: the coordinates defining the region to zoom on
//XT: Data for the restricted GTM - generated by RestrictedLikelihood
//SLlog: to store messages
var
  matX0, matX1, matY1: TMatrix;
  ik,id: integer;
begin
  //Compute the zoomed manifold
  SLlog.Add('...Compute new weight matrix');
  DimMatrix(matX0,acGTM.K,3);
  DimMatrix(matX1,acGTM.K,2);
  DimMatrix(matY1,acGTM.K,acGTM.D);
  for ik:=1 to acGTM.K do begin
      matX1[ik,1]:=(acGTM.matX[ik,1]*(xmax-xmin)/2+(xmax+xmin)/2);
      matX1[ik,2]:=(acGTM.matX[ik,2]*(ymax-ymin)/2+(ymax+ymin)/2);
  end;
  acGTM.MapToSpace(matX1,matY1);//matY1 is the zoomed manifold in original frame
  //
  zcGTM.istd:=acGTM.istd;
  zcGTM.beta:=acGTM.beta;//Transfer the width of the GTM to the zoomed GTM
  (zcGTM as TGTMFull).SetX(XT);//Load a data matrix -> the frame have changed
  zcGTM.Restart:=True; // Do not compute PCA, a starting manifold and a new value of std dev (beta).
  zcGTM.Init1(acGTM.K,acGTM.M,acGTM.sigma,acGTM.alpha,acGTM.iScaleInit,acGTM.fScaleInit); //Beware W is not set yet. The matrix dist2 is not set as well as 3D manifold coordinates (matY)
  //Copy PC123 in Zoomed map
  zcGTM.DimPC123;
  zcGTM.SetPC123mat(acGTM.PC123);
  //Get the same matrices M, X and Phi from the original GTM - very important, otherwise a numerical error may propagate an prevent the saved GTM function correctly
  zcGTM.SetMatM(acGTM.matM);
  zcGTM.SetMatX(acGTM.matX);
  zcGTM.SetPhi();
  //Translate and scale the zoomed manifold to the new frame
  for ik:=1 to zcGTM.K do
    for id:=1 to zcGTM.D do
      matY1[ik,id]:=((matY1[ik,id]*acGTM.SD[id]+acGTM.Mean[id])-zcGTM.Mean[id])/zcGTM.SD[id];
  //Set the new weights according to this manifold
  zcGTM.SetW(matY1);//W has been verified: it can be used to recompute matY with good precision
  zcGTM.UpdateMatY(False); //Check W...
  // Constrain the border - remove while debugging this feature
  xmin:=-1+2.0*zcGTM.rnode; //xmin,... are recycled
  xmax:= 1-2.0*zcGTM.rnode;
  ymin:=-1+2.0*zcGTM.rnode;
  ymax:= 1-2.0*zcGTM.rnode;
  for ik:=1 to zcGTM.K do begin // Selected nodes are allowed to move, non-selected are constrained.
    if (zcGTM.matX[ik,1]<=xmin) or (zcGTM.matX[ik,1]>=xmax) or (zcGTM.matX[ik,2]<=ymin) or (zcGTM.matX[ik,2]>=ymax) then begin
      zcGTM.SelNode[ik]:=False;
    end
    else
      zcGTM.SelNode[ik]:=True;
  end;//The border is now constrained
  //Start optimization of the zoom
  SLlog.Add('...Zoom optimization');
  ProjectOnZoom(zcGTM,SLlog,MaxIter,convCriteria);
end;

{procedure ProjectOnZoom(zcGTM: TcGTM; MaxIter: integer; SLlog: TStringList; XT: TMatrix; out LLt as double);
}

{procedure ProjectOnZoom(zcGTM: TcGTM; MaxIter: integer; SLlog: TStringList; out LLt as double);
}

procedure ProjectOnZoom(zcGTM: TcGTM; SLlog: TStringList; XT: TMatrix;
  const MaxIter: integer; const convCriteria: double);
//Project data on the zoomed GTM providing a data matrix
//zcGTM: the zoomed GTM model - must has been fully initialized including recentered
//MaxIter: maximum number of iterations for re-optimisation of the manifold (0 means no optimisation)
//SLlog: to store log messages
//XT: the data to project on
//LLt: output the likelihood after optimization
begin
  (zcGTM as TGTMFull).SetX(XT);//Load a data matrix -> the frame have changed
  ProjectOnZoom(zcGTM,SLlog,MaxIter);
end;

procedure ProjectOnZoom(zcGTM: TcGTM; SLlog: TStringList;
  const MaxIter: integer; const convCriteria: double);
//Project data on the zoomed GTM assuming a dataset has already been loaded.
//zcGTM: the zoomed GTM model
//MaxIter: maximum number of iterations for re-optimisation of the manifold (0 means no optimisation)
//SLlog: to store log messages
//LLt: output the likelihood after optimization
var
  dLL,DW: double;
  LLt,LLt0,DW0,dConv: double;
  id,im: Integer;
  iter: integer;
  bConv: boolean;
  sline: string;
  Wold: TMatrix;
begin
  //Project the dataset and compute the initial likelihood before starting the optimization.
  zcGTM.Project(False,True,True,False);//For initial step the manifold is constrained at its borders
  zcGTM.Expectation();//Yet, responsibilities on all nodes are required at this stage
  //zcGTM.Project(False,False,True,True);//For initial step the manifold is free to move
  DimMatrix(Wold,zcGTM.D,zcGTM.M); // Record the current version of the weights to compare them from an iteration to the other
  for id:=1 to zcGTM.D do
    for im:=1 to zcGTM.M do
      Wold[id,im]:=zcGTM.W[id,im];
  LLt0:=zcGTM.LogLikelyHood();
  iter:=0;
  DW0:=zcGTM.D*zcGTM.M;
  bConv:=False;
  while (iter<MaxIter) and (bConv=False) do
  begin
    Inc(iter);
    zcGTM.Maximization();
    zcGTM.ExpectationOnSelected();
    LLt:=zcGTM.LogLikelyHood();
    sline:='Iter.: '+IntToStr(Iter)+' LLmap='+FloatToStrF(LLt,ffFixed,8,5)+' ';
    if iter>1 then
    begin
      dLL:=LLt-LLt0;
      sline:=sline+'DLLmap='+FloatToStrF(dLL,ffFixed,8,5)+' %DLLmap='+FloatToStrF(abs((dLL)*100/LLt0),ffFixed,8,5);
      // How much did the map changed
      DW:=0;
      for id:=1 to zcGTM.D do
        for im:=1 to zcGTM.M do
        begin
          if (DW<abs(Wold[id,im]-zcGTM.W[id,im])) then DW:=abs(Wold[id,im]-zcGTM.W[id,im]);
          Wold[id,im]:=zcGTM.W[id,im];
        end;
      dConv:=DW/DW0;
      sline:=sline+' DW='+FloatToStrF(DW,ffFixed,8,5)+' %DW='+FloatToStrF(dConv*100,ffFixed,8,5);
      If dLL<ConvCriteria then bConv:=True;
    end;
    SLlog.Add(sline);  Application.ProcessMessages;//APP_PROCESS;
    //Prepare next iteration
    LLt0:=LLt;
  end;
  if MaxIter>0 then zcGTM.Project(False,True,False,False);
end;

function ProjectData(myGTM: TGTMFull; TZ: TMatrix; Nmax: integer; b3D: boolean; s3Dfile: string): double;
var
  sl: TStringList;
  Z3D: TMatrix;
  jj,ii,id: integer;
  LLt: Double;
  fsOut: TFileStream;
begin
  sl:=TStringList.Create;
  if (Nmax>0) then
  begin
    myGTM.Project(TZ,Nmax);
    LLt:=myGTM.LogLikelyHood();
    if b3D then
    begin
      sl.Clear;
      PrintMat(myGTM.Z,'Z',1,myGTM.N,1,myGTM.D,sl);
      if not FileExists(s3Dfile+'Z.mat') then
        sl.SaveToFile(s3Dfile+'Z.mat')
      else
      begin
        fsOut:=TFileStream.Create(s3Dfile+'Z.mat',fmOpenReadWrite);
        fsOut.Seek(0,soFromEnd);
        sl.SaveToStream(fsOut);
        FreeAndNil(fsOut);
      end;
      DimMatrix(Z3D,High(myGTM.Z),3);
      for ii:=1 to High(Z3D) do
        for jj:=1 to 3 do
        begin
          Z3D[ii,jj]:=0;
          for id:=1 to myGTM.D do
            Z3D[ii,jj]:=Z3D[ii,jj]+myGTM.Z[ii,id]*myGTM.PC123[id,jj];
        end;
      sl.Clear;
      PrintMat(Z3D,'Z3D',1,myGTM.N,1,3,sl);
      if not FileExists(s3Dfile+'Z3D.mat') then
        sl.SaveToFile(s3Dfile+'Z3D.mat')
      else
      begin
        fsOut:=TFileStream.Create(s3Dfile+'Z3D.mat',fmOpenReadWrite);
        fsOut.Seek(0,soFromEnd);
        sl.SaveToStream(fsOut);
        FreeAndNil(fsOut);
      end;
    end;
  end else
  begin
    (myGTM as TGTMBase).Project();
    LLt:=myGTM.LogLikelyHood();
  end;
  Result:=LLt;
  sl.Clear;
  FreeAndNil(sl);
end;

function ProjectDataOnSelected(myGTM: TcGTM; TZ: TMatrix; Nmax: integer; var LLt: double; b3D: boolean; s3Dfile: string): double;
var
  sl: TStringList;
  Z3D: TMatrix;
  jj,ii,id: integer;
  fsOut: TFileStream;
begin
  sl:=TStringList.Create;
  if (Nmax>0) then
  begin
    //myGTM.ProjectOnSelected(TZ,Nmax);
    LLt:=myGTM.LogLikelyHoodOnSelected();
    if b3D then
    begin
      sl.Clear;
      PrintMat(myGTM.Z,'Z',1,myGTM.N,1,myGTM.D,sl);
      if not FileExists(s3Dfile+'Z.mat') then
        sl.SaveToFile(s3Dfile+'Z.mat')
      else
      begin
        fsOut:=TFileStream.Create(s3Dfile+'Z.mat',fmOpenReadWrite);
        fsOut.Seek(0,soFromEnd);
        sl.SaveToStream(fsOut);
        FreeAndNil(fsOut);
      end;
      DimMatrix(Z3D,High(myGTM.Z),3);
      for ii:=1 to High(Z3D) do
        for jj:=1 to 3 do
        begin
          Z3D[ii,jj]:=0;
          for id:=1 to myGTM.D do
            Z3D[ii,jj]:=Z3D[ii,jj]+myGTM.Z[ii,id]*myGTM.PC123[id,jj];
        end;
      sl.Clear;
      PrintMat(Z3D,'Z3D',1,myGTM.N,1,3,sl);
      if not FileExists(s3Dfile+'Z3D.mat') then
        sl.SaveToFile(s3Dfile+'Z3D.mat')
      else
      begin
        fsOut:=TFileStream.Create(s3Dfile+'Z3D.mat',fmOpenReadWrite);
        fsOut.Seek(0,soFromEnd);
        sl.SaveToStream(fsOut);
        FreeAndNil(fsOut);
      end;
    end;
  end else
  begin
    (myGTM as TGTMBase).Project();
    LLt:=myGTM.LogLikelyHood();
  end;
  Result:=LLt;
  sl.Clear;
  FreeAndNil(sl);
end;

function ProjectDataFomManifold(myGTM: TcGTM; TZ: TMatrix; Nmax: integer; var LLt: double; b3D: boolean; s3Dfile: string): double;
var
  sl: TStringList;
  Z3D: TMatrix;
  jj,ii,id: integer;
  fsOut: TFileStream;
begin
  sl:=TStringList.Create;
  if (Nmax>0) then
  begin
    //myGTM.ProjectFromManifold(TZ,Nmax);
    //LLt:=myGTM.LogLikelyHoodFromManifold();
    if b3D then
    begin
      sl.Clear;
      PrintMat(myGTM.Z,'Z',1,myGTM.N,1,myGTM.D,sl);
      if not FileExists(s3Dfile+'Z.mat') then
        sl.SaveToFile(s3Dfile+'Z.mat')
      else
      begin
        fsOut:=TFileStream.Create(s3Dfile+'Z.mat',fmOpenReadWrite);
        fsOut.Seek(0,soFromEnd);
        sl.SaveToStream(fsOut);
        FreeAndNil(fsOut);
      end;
      DimMatrix(Z3D,High(myGTM.Z),3);
      for ii:=1 to High(Z3D) do
        for jj:=1 to 3 do
        begin
          Z3D[ii,jj]:=0;
          for id:=1 to myGTM.D do
            Z3D[ii,jj]:=Z3D[ii,jj]+myGTM.Z[ii,id]*myGTM.PC123[id,jj];
        end;
      sl.Clear;
      PrintMat(Z3D,'Z3D',1,myGTM.N,1,3,sl);
      if not FileExists(s3Dfile+'Z3D.mat') then
        sl.SaveToFile(s3Dfile+'Z3D.mat')
      else
      begin
        fsOut:=TFileStream.Create(s3Dfile+'Z3D.mat',fmOpenReadWrite);
        fsOut.Seek(0,soFromEnd);
        sl.SaveToStream(fsOut);
        FreeAndNil(fsOut);
      end;
    end;
  end else
  begin
    (myGTM as TGTMBase).Project();
    LLt:=myGTM.LogLikelyHood();
  end;
  Result:=LLt;
  sl.Clear;
  FreeAndNil(sl);
end;

end.

