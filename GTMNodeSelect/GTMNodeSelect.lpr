program GTMNodeSelect;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Classes, SysUtils, CustApp
  { you can add units after this },
  StrUtils,Contnrs,math,streamex,utypes,ulinalg,UGTMBase,UGTMFull,UGTMSparse, UcGTM,
  UGTMXML,XMLRead, XMLWrite, DOM, UnitLLStringList, UnitNodeSelectProc;
const
  ShrtArgs='hi:x:o:n:b:t:g:c:z:';
  LongArgs='help input: model: output: nodes: box: threshold: blocks:'+
           'generate: nIter: limit: SDF: FileList:';
type

  { TGTMNodeSelect }

  TGTMNodeSelect = class(TCustomApplication)
  protected
    procedure DoRun; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    procedure WriteHelp; virtual;
  end;

{ TGTMNodeSelect }

procedure TGTMNodeSelect.DoRun;
type
  Tselmode=(LST,RNG,UNK);

var
  ErrorMsg: String;
  smols,smodel,snodes,sdata,sbox,soutput,sthrld,sblocks,sline,stmp: string;
  sSDF: string; //SDF file
  sFileList: string; // To process a file list
  sdConv,sMaxIter: string;
  //RF: TFileReader;
  SLnodes,SLbox: TStringList;
  SLmols:TLLStringList;
  SLFileList: TStringList; // a list of files - 1 title line, 1 molecule per line
  SLtmp: TStringList;
  SLlog: TStringList;
  OLSDF: TObjectList;
  ii,ii1,ik{,im}: integer;
  nseed,ngenerate: integer;
  aselmode: Tselmode;
  //pd:PIdxDble;
  //
  //docin,docout: TDOMDocument;//docin GTM model; docout GTM model updated
  //parent,child,node: TDOMNode;
  aGTMXML: TGTMXML;
  aGTMBase: TGTMBase;
  acGTM,zcGTM: TcGTM;//a GTM and the zoomed GTM
  aGTMSparse: TGTMSparse;
  xmin,xmax,ymin,ymax,thrld: double;
  iter,MaxIter,id,im: integer;
  bConv: boolean;
  {Nmax,}nBlocks: integer;
  LLt,LLtmin,LLt0,dLL,DW,DW0,dConv: Double;
  Wold: TMatrix;
  matX0,matX1,matY1,XT{,ZT}: TMatrix;
  aSmpleX, aSmpleZ:TMatrix;
  bgenerate, bselnode, bzoom: boolean;
  //pLL: PDouble;
  function sCheckRange(s: string): double; //check the range [-1,1] of a number represented as a string
  var
    d: double;
    e: integer;
  begin
    e:=0;
    d:=0;
    Result:=NaN;
    try
      Val(s,d,e);
    except
      Exception.Create('ERROR: try to convert '+s+' to double. Beware to locale.');
      Halt;
    end;
    if (d<-1) or (d>1) then Result:=NaN else Result:=d
  end;
begin
  // quick check parameters
  ErrorMsg:=CheckOptions(ShrtArgs, LongArgs);
  if ErrorMsg<>'' then begin
    ShowException(Exception.Create(ErrorMsg));
    Terminate;
    Exit;
  end;
  smols:='';
  smodel:='';
  soutput:='default';
  snodes:='';
  sdata:='';
  sbox:='';
  sFileList:='';
  sSDF:='';
  sthrld:='';
  sblocks:='';
  sdConv:='';
  sMaxIter:='';
  stmp:='';
  xmin:=-1;
  xmax:=1;
  ymin:=-1;
  ymax:=1;
  LLt:=MinDouble;
  LLtmin:=MinDouble;
  nBlocks:=-1;
  MaxIter:=0;
  dConv:=0.01;
  thrld:=NaN;
  ngenerate:=0;
  nseed:=-1;
  bgenerate:=False;
  bselnode:=False;
  bzoom:=False;
  aselmode:=UNK;
  aGTMBase:=nil;
  acGTM:=nil;
  acGTM:=nil;
  aGTMSparse:=nil;
  aGTMXML:=nil;
  matX0:=nil;
  matX1:=nil;
  matY1:=nil;
  XT:=nil;
  aSmpleX:=nil;
  aSmpleZ:=nil;
  SLnodes:=TStringList.Create;
  SLbox:=TStringList.Create;
  SLFileList:=TStringList.Create;
  SLmols:=TLLStringList.Create;
  SLtmp:=TStringList.Create;
  SLlog:=TStringList.Create;
  OLSDF:=TObjectList.Create; OLSDF.OwnsObjects:=True;
  // parse parameters
  if HasOption('h', 'help') then begin
    WriteHelp;
    Terminate;
    Exit;
  end;
  if HasOption('i','input') then begin
    smols:=GetOptionValue('i','input');
    bselnode:=True;
  end;
  if HasOption('x','model') then begin
    smodel:=GetOptionValue('x','model');
  end else begin
    WriteHelp;
    Terminate;
    Exit;
  end;
  if HasOption('o','output') then begin
    soutput:=GetOptionValue('o','output');
  end;
  if HasOption('n','nodes') then begin
    snodes:=GetOptionValue('n','nodes');
    SLnodes.Clear;
    SLnodes.CommaText:=snodes;
    aselmode:=LST;
  end;
  if HasOption('b','box') then begin
    sbox:=GetOptionValue('b','box');
    sbox:=Copy(sbox,2,Length(sbox)-2);
    SLbox.Clear;
    SLbox.CommaText:=sbox;
    aselmode:=RNG;
    if SLbox.Count<>4 then begin
      WriteHelp;
      Terminate;
      Exit;
    end;
    if bselnode then bzoom:=True;
  end;
  if HasOption('c','nIter') then begin
    sMaxIter:=GetOptionValue('c','nIter');
    try
      MaxIter:=StrToInt(sMaxIter);
    except
      Exception.Create('ERROR: invalid maximum number of iterations');
      WriteHelp;
      Terminate;
      Exit;
    end;
  end;
  if HasOption('z','limit') then begin
    sMaxIter:=GetOptionValue('z','limit');
    try
      dConv:=StrToFloat(sdConv);
    except
      Exception.Create('ERROR: invalid convergence criteria');
      WriteHelp;
      Terminate;
      Exit;
    end;
  end;
  if HasOption('t','threshold') then begin
    sthrld:=GetOptionValue('t','threshold');
    try
      thrld:=StrToFloat(sthrld);
    except
      Exception.Create('ERROR: Impossible to convert threshold value: '+sthrld);
      WriteHelp;
      Terminate;
      Exit;
    end;
    if (thrld<0) or (thrld>1) then
    begin
      Exception.Create('ERROR: threshold value must be within range [0,1]');
      WriteHelp;
      Terminate;
      Exit;
    end;
  end;
  if HasOption('g','generate') then begin
    bgenerate:=True;
    ngenerate:=StrToInt(GetOptionValue('g','generate'));
  end;
  if HasOption('seed') then
  begin
    nseed:=StrToInt(GetOptionValue('seed'));
  end;
  if HasOption('SDF') then
  begin
    sSDF:=GetOptionValue('SDF');
    LoadSDF(sSDF,OLSDF);
  end;
  if HasOption('FileList') then
  begin
    sFileList:=GetOptionValue('FileList');
    sFileList:=Copy(sFileList,2,Length(sFileList)-2);
    SLFileList.Clear;
    SLFileList.CommaText:=sFileList;
    if SLFileList.Count<1 then begin
      Writeln('ERROR: Can''t intepret file list: '+sFileList);
      WriteHelp;
      Terminate;
      Exit;
    end;
    for ii:=0 to SLFileList.Count-1 do
    begin
        stmp:=SLFileList[ii];
        if not FileExists(stmp) then
        begin
           Writeln('ERROR: Can''t locate file: '+stmp);
           WriteHelp;
           Terminate;
           Exit;
        end;
    end;
  end;
  if HasOption('blocks') then begin
    sblocks:=GetOptionValue('blocks');
    try
      nBlocks:=StrToInt(sblocks);
    except
      Exception.Create('ERROR: Can''t to interpret block size value: '+sblocks);
      WriteHelp;
      Terminate;
      Exit;
    end;
    if (nBlocks<1) then
    begin
      Exception.Create('ERROR: Block size must be >1');
      WriteHelp;
      Terminate;
      Exit;
    end;
  end;
  if aselmode=UNK then
  begin
      WriteHelp;
      Terminate;
      Exit;
  end;

  { add your program here }
  if (bselnode) and (smols='') then begin
    raise Exception.Create('ERROR GTMNodeSelect: molecules are mandatory for restrained likelihood calculation');
    WriteHelp;
    Terminate;
    Exit;
  end;
  if (not bgenerate) and (smols='') then begin
    raise Exception.Create('ERROR GTMNodeSelect: molecules are mandatory for zooming');
    WriteHelp;
    Terminate;
    Exit;
  end;
  if nseed>=0 then RandSeed:=nseed else randomize; //Control of pseudo-random number generator
  Writeln('******************************************************************');
  Writeln('*                                                                *');
  Writeln('*                     ISIDA/GTMNodeSelect                        *');
  Writeln('*        Select nodes for data generation and zoom               *');
  Writeln('*                                                                *');
  Writeln('* G. Marcou, Université de Strasbourg                      2023  *');
  Writeln('******************************************************************');
  Writeln;
  Writeln('GTM model: '+smodel);
  // Restrict the application to full size GTM
  acGTM:=TcGTM.Create;
  acGTM.Restart:=True;//This GTM is supposed to have been already trained
  aGTMXML:=TGTMXML.Create;
  aGTMXML.ReadGTMModel(acGTM,smodel);
  FreeAndNil(aGTMXML);
  //Node selection
  if aselmode=LST then begin
    snodes:=' ';//snodes: string of selected nodes IDs
    for ii:=0 to SLnodes.Count-1 do begin
      ik:=StrToInt(SLnodes[ii]);
      acGTM.SelNode[ik]:=True;
      snodes:=snodes+IntToStr(ik)+' ';
    end;
    Writeln('List of selected nodes: ('+snodes+')');
    Writeln(snodes);
  end else if aselmode=RNG then begin
    Writeln('Submanifold definition...');
    xmin:=sCheckRange(SLbox[0]);
    xmax:=sCheckRange(SLbox[1]);
    ymin:=sCheckRange(SLbox[2]);
    ymax:=sCheckRange(SLbox[3]);
    if (xmin>=xmax) or (ymin>=ymax) then begin
      Exception.Create('ERROR: wrong range value: '+sbox);
      Halt;
    end;
    //
    Writeln('Concerned nodes ID:');
    snodes:=' ';//snodes: string of selected nodes IDs
    for ik:=1 to acGTM.K do begin //SelNode=TRUE -> node is selected to be used for projection and it is updatable during optimization
      if (acGTM.matX[ik,1]>=xmin) and (acGTM.matX[ik,1]<=xmax) and (acGTM.matX[ik,2]>=ymin) and (acGTM.matX[ik,2]<=ymax) then begin
        acGTM.SelNode[ik]:=True;
        snodes:=snodes+IntToStr(ik)+' ';
      end
      else
        acGTM.SelNode[ik]:=False;
    end;
    Writeln('('+snodes+')');
  end else begin
    Exception.Create('ERROR: unknown node selection request.');
  end;
  //Restricted Likelihood
  if (bselnode) then begin
    //Load the molecules into the molecule list and the GTM.
    SLmols.LoadFromFile(smols);
    acGTM.ReadMols(smols);
    //RestrictedLikelyhood(SLmols,acGTM,thrld,XT,LLt,LLtmin,SLtmp,SLlog);
    RestrictedLikelyhood(SLmols,acGTM,thrld,LLt,LLtmin,SLlog);
    Writeln(SLlog.Text);
    SLlog.Clear;
    //Output the selected molecules sorted according to their likelyhood int the file *_Sorted.svm
    SLmols.SaveToFile(soutput+'_Sorted.svm');
    // Filter the SDF
    if sSDF<>'' then
    begin
      FilterByLikelyhood(acGTM,LLtmin,OLSDF);
      WriteSDF(copy(sSDF,1,RPos('.',sSDF)-1)+'_Selected.sdf',OLSDF);
    end;
    // Filter requested files
    for ii:=0 to SLFileList.Count-1 do
    begin
      stmp:=SLFileList[ii];
      SLtmp.Clear;
      SLtmp.LoadFromFile(stmp);
      FilterByLikelyhood(acGTM,LLtmin,SLtmp);
      SLtmp.SaveToFile(copy(stmp,1,RPos('.',stmp)-1)+'_Selected'+copy(stmp,RPos('.',stmp),Length(stmp)));
    end;
    // Filter the X matrix
    FilterByLikelyhood(acGTM,LLtmin,XT);
    //
    SLtmp.Clear;
  end;
  //Sample generation
  if bgenerate then begin
    GeneratedFromSelected(acGTM,ngenerate,aSmpleX,aSmpleZ);
    SLtmp.Clear;
    PrintMat(aSmpleX,'SampleX',1,ngenerate,1,acGTM.D,SLtmp);//In the initial space of the data
    SLtmp.SaveToFile(ChangeFileExt(soutput,'X.mat'));
    SLtmp.Clear;
    PrintMat(aSmpleZ,'SampleZ',1,ngenerate,1,acGTM.D,SLtmp);
    SLtmp.SaveToFile(ChangeFileExt(soutput,'Z.mat'));//In the frame set of the manifold
  end;
  //Zoom
  if bzoom then begin
    zcGTM:=TcGTM.Create;
    SLlog.Clear;
    DoZoomOnGTM(acGTM,zcGTM,xmax,xmin,ymax,ymin,XT,SLlog,MaxIter);
    Writeln(SLlog.Text);
    {
    //Compute the zoomed manifold
    Writeln('...Compute new weight matrix');
    DimMatrix(matX0,acGTM.K,3);
    DimMatrix(matX1,acGTM.K,2);
    for ik:=1 to acGTM.K do begin
        matX1[ik,1]:=(acGTM.matX[ik,1]*(xmax-xmin)/2+(xmax+xmin)/2);
        matX1[ik,2]:=(acGTM.matX[ik,2]*(ymax-ymin)/2+(ymax+ymin)/2);
    end;
    DimMatrix(matY1,acGTM.K,acGTM.D);
    acGTM.MapToSpace(matX1,matY1);//matY1 is the zoomed manifold in original frame

    {LLt:=acGTM.LogLikelyHoodFromManifold(matY1); //Loglikelihood and responsibilities have been estimated
    Writeln('...Computing projections');
    TGTMFull(acGTM).Project(); //Compute projections
    Writeln('Saving files');
    WriteGTMMat(acGTM,soutput+'0',True,False);}

    //
    zcGTM:=TcGTM.Create;
    zcGTM.Restart:=True;
    zcGTM.istd:=acGTM.istd;
    zcGTM.beta:=acGTM.beta;//Transfer the width of the GTM to the zoomed GTM
    (zcGTM as TGTMFull).SetX(XT);//Load a data matrix -> the frame have changed
    zcGTM.Init1(acGTM.K,acGTM.M,acGTM.sigma,acGTM.alpha,acGTM.iScaleInit,acGTM.fScaleInit); //Beware W is not set yet
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
    Writeln('...Zoom optimization');
    DimMatrix(Wold,zcGTM.D,zcGTM.M);
    //Project the dataset and compute the initial likelihood before starting the optimization.
    zcGTM.Project(False,False,True,True);//Needed to update the dist2
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
        If dLL<dConv then bConv:=True;
      end;
      WRITELN(sline);//APP_PROCESS;
      //Prepare next iteration
      LLt0:=LLt;
    end;
    }
    //Projection and saving
    Writeln('...Computing projections');
    zcGTM.Project(False,False,True,True); //Compute projections
    Writeln('...Saving files');
    WriteGTMMat(zcGTM,soutput,False,False);
    Writeln('...Save zoom GTM model');
    aGTMXML:=TGTMXML.Create;
    aGTMXML.WriteGTMModel(zcGTM,soutput+'.xml');
    FreeAndNil(aGTMXML);
    //Release memory
    FreeAndNil(zcGTM);

    {//Recompute a weight matrix an select perimeter nodes
    Writeln('...Compute new weight matrix');
    acGTM.SetW(matY1);
    acGTM.UpdateMatY(False);
    xmin:=-1+2.0*acGTM.rnode; //xmin,... are recycled
    xmax:= 1-2.0*acGTM.rnode;
    ymin:=-1+2.0*acGTM.rnode;
    ymax:= 1-2.0*acGTM.rnode;
    for ik:=1 to acGTM.K do begin
      if (acGTM.matX[ik,1]<=xmin) or (acGTM.matX[ik,1]>=xmax) or (acGTM.matX[ik,2]<=ymin) or (acGTM.matX[ik,2]>=ymax) then begin
        acGTM.SelNode[ik]:=True;
        Write(' '+IntToStr(ik));
      end
      else
        acGTM.SelNode[ik]:=False;
    end;writeln;

    DimMatrix(Wold,acGTM.D,acGTM.M);
    LLt0:=acGTM.LogLikelyHood();
    iter:=0;
    DW0:=acGTM.D*acGTM.M;
    bConv:=False;
    repeat
      acGTM.Maximization();
      acGTM.Expectation();
      LLt:=acGTM.LogLikelyHood();
      sline:='Iter.: '+IntToStr(Iter)+' LLmap='+FloatToStrF(LLt,ffFixed,8,5)+' ';
      if iter>1 then
      begin
        dLL:=LLt-LLt0;
        sline:=sline+'DLLmap='+FloatToStrF(dLL,ffFixed,8,5)+' %DLLmap='+FloatToStrF(abs((dLL)*100/LLt0),ffFixed,8,5);
        // How much did the map changed
        DW:=0;
        for id:=1 to acGTM.D do
          for im:=1 to acGTM.M do
          begin
            if (DW<abs(Wold[id,im]-acGTM.W[id,im])) then DW:=abs(Wold[id,im]-acGTM.W[id,im]);
            Wold[id,im]:=acGTM.W[id,im];
          end;
        dConv:=DW/DW0;
        sline:=sline+' DW='+FloatToStrF(DW,ffFixed,8,5)+' %DW='+FloatToStrF(dConv*100,ffFixed,8,5);
        If dLL<dConv then bConv:=True;
      end;
      WRITELN(sline);//APP_PROCESS;
      //Prepare next iteration
      LLt0:=LLt;
      Inc(iter);
    until (iter>MaxIter) or (bConv=True);


    Writeln('...Computing projections');
    acGTM.Project(False,False,True,True); //Compute projections
    Writeln('Saving files');
    WriteGTMMat(acGTM,soutput,True,False);
    }
    {
    Writeln('...Computing submanifold loglikelihood and responsibilities');
    LLt:=acGTM.LogLikelyHoodFromManifold(matY1); //Loglikelihood and responsibilities have been estimated
    Writeln('...Computing projections');
    TGTMFull(acGTM).Project(); //Compute projections
    Writeln('Saving files');
    WriteGTMMat(acGTM,soutput,True,False);
    //Recompute a weight matrix an select perimeter nodes
    Writeln('...Compute new weight matrix');
    acGTM.SetW(matY1);
    acGTM.UpdateMatY(False);
    xmin:=-1+2.0*acGTM.rnode; //xmin,... are recycled
    xmax:= 1-2.0*acGTM.rnode;
    ymin:=-1+2.0*acGTM.rnode;
    ymax:= 1-2.0*acGTM.rnode;
    for ik:=1 to acGTM.K do begin
      if (acGTM.matX[ik,1]<=xmin) or (acGTM.matX[ik,1]>=xmax) or (acGTM.matX[ik,2]<=ymin) or (acGTM.matX[ik,2]>=ymax) then begin
        acGTM.SelNode[ik]:=True;
        Write(' '+IntToStr(ik));
      end
      else
        acGTM.SelNode[ik]:=False;
    end;
    }
    {for ik:=1 to acGTM.K do begin
        matX0[ik,1]:=acGTM.matX[ik,1];
        matX0[ik,2]:=acGTM.matX[ik,2];
        if acGTM.SelNode[ik] then matX0[ik,3]:=1 else matX0[ik,3]:=0;
    end;
    PrintMat(matX0,'matX0',1,acGTM.K,1,3,SLtmp);
    SLtmp.SaveToFile(soutput+'_matX0.mat');
    Writeln;}
  end;
  //Save new GTM model
  if (not bzoom) and bselnode then begin
    Writeln('Save new GTM model');
    aGTMXML:=TGTMXML.Create;
    aGTMXML.WriteGTMModel(acGTM,soutput+'.xml');
    FreeAndNil(aGTMXML);
  end;
  // stop program loop
  FreeAndNil(SLnodes);
  FreeAndNil(SLbox);
  FreeAndNil(SLmols);
  FreeAndNil(SLtmp);
  FreeAndNil(SLlog);
  FreeAndNil(SLFileList);
  FreeAndNil(OLSDF);
  if aGTMXML<>nil then FreeAndNil(aGTMXML);
  if aGTMBase<>nil then FreeAndNil(aGTMBase);
  if acGTM<>nil then FreeAndNil(acGTM);
  if aGTMSparse<>nil then FreeAndNil(aGTMSparse);
  Terminate;
end;

constructor TGTMNodeSelect.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  StopOnException:=True;
end;

destructor TGTMNodeSelect.Destroy;
begin
  inherited Destroy;
end;


procedure TGTMNodeSelect.WriteHelp;
begin
  { add your help code here }
  writeln('Usage: ', ExeName, ' -h -i <molecules.svm> -x <GTMmode.xml> '+
          '-o <output> {-n <nodeID1,nodeID2,...,nodeIDn> | '+
          '-c <iterations> -z <convergence>-b [<xmin,xmax,ymin,ymax>]} '+
          '-t <threshold> -g <sample size> '+
          '--blocks <block size> -R [<responsibility offset>] --Heating '+
          '--seed <integer> ---SDF <file.sdf> --FileList [file1,file2]');
  writeln('-i, --input: molecules to be used for projection and further training of the GTM');
  writeln('-x, --model: the GTM model on which to zoom in or from which to generate new data point');
  writeln('-o, --output: output base name');
  writeln('-n, --nodes: list of nodes to select');
  writeln('-t, --threshold');
  writeln('-g, --generate: number of data points to sample');
  writeln('-b, --box select nodes inside a rectangular box on the manifold');
  writeln('-c, --nIter: number of iterations for zoom optimization');
  writeln('-z, --limit: convergence criteria for zoom optimization');
  writeln('--block');
  writeln('--seed: a positive integer to set the seed of the pseudo-random number generator');
  writeln('--SDF: an SDF to regenerate from an new SDF based on selected data');
  writeln('--FileList: a list of files between squared brackets to process based on selected data. File format: 1 title line, 1 line / molecule.');
end;

var
  Application: TGTMNodeSelect;
begin
  {$IfDef WINDOWS}DefaultFormatSettings.DateSeparator:='-';{$EndIf}
  {$IfDef LOCALES}DefaultFormatSettings.DecimalSeparator:='.';DefaultFormatSettings.ShortDateFormat:='d/m/y';{$EndIf}
  Application:=TGTMNodeSelect.Create(nil);
  Application.Title:='GTMNodeSelect';
  Application.Run;
  Application.Free;
end.

