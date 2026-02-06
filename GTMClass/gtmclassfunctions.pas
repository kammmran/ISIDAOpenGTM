unit GTMClassFunctions;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, strutils, streamex, XMLRead, XMLWrite, DOM, utypes, math, UGTMClass,ulinalg, UnitClsStats;

type
    TArr2D = array of array of double;
    checkedMols = array of integer;
    ClassArray_type = array of integer;
    predClasses_type = array of array of integer;
    integer_vector = array of integer;
    double_vector = array of double;
    XMLData = record
      P_ci_xk : TArr2D;
      classesList: array of integer;
      MinRespAD: double;
      node_number: integer;
      MinRespLS: double;
      classNormalization: boolean;
    end;
    PTRespClass=^TRespClass;
    TRespClass=record
      resp: double;
      iClass: integer;
      sClass: string;
    end;

  function readRespFile(file_name: String; out nInst: integer; out nNodes: integer; kNodes: integer =0): TArr2D;
  function checkMolsForAD(resp_array: TArr2D; ADthreshold: real): checkedMols;
  function readClassFile(file_name: String; mols_list_in_AD: array of integer; out comment: string): ClassArray_type;
  function getFirstItemPositionInArray_of_INT(item: integer; arrayToSearch: array of integer): integer;
  function getClasses(classArray: array of integer): ClassArray_type;
  function countMolsInClass(classArray: array of integer; classNumnber: integer): integer;
  function sortArray_INT(arrayToSort: ClassArray_type): ClassArray_type;
  procedure saveLandscape(outName: string; author: string; aGTMCl: TGTMClass; title,property_comment: string);
  function readLandscape(fileName: string): XMLData;
  procedure readLandscape(fileName: string; var aGTMCl: TGTMClass);
  procedure writeOut(outName: string; array_of_lines: array of string);
  function maxClasses(vector: array of double; classes: array of integer): integer;
  function IsNullOrWhiteSpace(s: string): Boolean;
  procedure TrainLandscape(aGTMClass: TGTMClass; trRspFileNme, trPrpFileNme, sOutFileName, sAuthor, sTitle, sComment: string; SLlog: TStrings);
  procedure TrainLandscape(aGTMClass: TGTMClass; trRspPrp: TStringList; sOutFileName, sAuthor, sTitle, sComment: string; SLlog: TStrings);//trRspPrp, property is a double associated to the corresponding responsibilities string
  procedure UseLandscape(aGTMClass: TGTMClass; teRspFileNme, sOutFileName: string; SLlog: TStrings); // Use the landscape for predictions only - no class statistics
  procedure UseLandscape(aGTMClass: TGTMClass; teRsp: TStringList; sOutFileName: string; aClsStat: TClsStats; SLlog: TStrings);  // Use the landscape and manage the class statistics

implementation

function getFirstItemPositionInArray_of_INT(item: integer; arrayToSearch: array of integer): integer; {check whether specified item is in array and returns the first position of it in array. If item is not in the array then it returns -1}
var
  position: integer;
  index: integer;
begin
  position:= -1;
  if length(arrayToSearch)>0 then
  begin
    for index:=0 to length(arrayToSearch)-1 do
    begin
      if arrayToSearch[index]=item then
      begin
        position:=index;
        break;
      end;
    end;

  end;
  getFirstItemPositionInArray_of_INT:= position;
end;

function readRespFile(file_name: String; out nInst: integer; out nNodes: integer; kNodes: integer =0): TArr2D; {function to read new matR file; The first line and the last line are comments}
var
  //resp_array: TArr2D;
  f: textfile;
  line: String;
  line_index: integer;
  node_index : integer;
  column_index: integer;
  temp_resp_array: TStringList;
  temp_node_resp_array: TStringList;
begin
  assignfile(f, file_name);
  Result:=nil;
  nInst:=0;
  try
    line_index:=0;
    reset(f);
    while not eof(f) do
    begin
      readln(f, line);
      if (line<>'') then
      begin
        writeln('New line..');
        Inc(nInst);
        temp_resp_array:=TStringList.create;
        temp_node_resp_array:=TStringList.create;
        writeln('Increasing Result length..');
        SetLength(Result, (line_index+1));
        writeln('Initialization of TList..');
        temp_resp_array.Delimiter:=' ';
        temp_resp_array.StrictDelimiter := False;
        temp_resp_array.DelimitedText:=line;
        writeln('Initialization of TList for nodes..');
        temp_node_resp_array.Delimiter:=':';
        temp_node_resp_array.StrictDelimiter:=True;
        temp_node_resp_array.DelimitedText:= temp_resp_array[temp_resp_array.Count-1];
        nNodes := StrToInt(temp_node_resp_array[0]);
        if (kNodes<>0) and (kNodes<>nNodes) then
        begin
          writeln('ERROR readRespFile: Unexpected number of nodes reading file '+file_name);
          halt;
        end;
        node_index:=1;
        writeln('Increasing Result[line] length..');
        SetLength(Result[line_index], nNodes);
        writeln('For cycle..');
        for column_index:=1 to (nNodes) do
        begin
          temp_node_resp_array.DelimitedText:= temp_resp_array[node_index];
          if StrToInt(temp_node_resp_array[0])>column_index then begin
             Result[line_index, column_index-1]:= 0.0;
          end
          else begin
            Result[line_index, column_index-1]:= StrToFloat(temp_node_resp_array[1]);
            Inc(node_index);
          end;
        end;
        Inc(line_index);
        writeln(line_index);
        FreeAndNil(temp_node_resp_array);
        FreeAndNil(temp_resp_array);
        writeln('Finished the line..');
      end;
    end;
    close(f);
  except
    close(f);
    writeln('!!!An Error Occured During The Reading Of File With Responsibilities For The Color Set!!!');
  end;
end;

function checkMolsForAD(resp_array: TArr2D; ADthreshold: real): checkedMols; {function to remove molecules which are out of AD}
var
  molecule_index: integer;
  resp_index: integer;
  //mols_list: checkedMols;
  maxResp: real;
  list_index: integer;
begin
  list_index:=0;
  Result:=nil;
  SetLength(Result,Length(resp_array));
  for molecule_index:=Low(resp_array) to High(resp_array) do
  begin
    maxResp:=0.0;
    for resp_index:=Low(resp_array[molecule_index]) to High(resp_array[molecule_index]) do
    begin
      if resp_array[molecule_index][resp_index]>maxResp then
      begin
        maxResp:= resp_array[molecule_index][resp_index];
      end;
    end;
    if maxResp>=ADthreshold then
    begin
       //SetLength(Result, list_index+1);
       Result[molecule_index]:= molecule_index;
       Inc(list_index);
    end else Result[molecule_index]:=-1;
    if Result[molecule_index]=-1 then
       writeln('Molecule ', molecule_index, ' max resp is ', maxResp);
  end;
end;

function readClassFile(file_name: String; mols_list_in_AD: array of integer; out comment: string): ClassArray_type; {function to read new activity file; The first line is a comment}
var
  //class_array: ClassArray_type;
  f: textfile;
  line: String;
  line_index: integer;
begin
  assignfile(f, file_name);
  Result:=nil;
  try
    line_index:=0;
    reset(f);
    while not eof(f) do
    begin
      readln(f, line);
      if (line_index>0) and (line<>'') and (mols_list_in_AD[line_index-1]<>-1) then
      begin
        SetLength(Result, length(Result)+1);
        Result[High(Result)]:=StrToInt(line);
      end
      else if (line_index=0) then
      begin
        comment:=line;
      end;
      Inc(line_index);
    end;
    close(f);
  except
    close(f);
    writeln('!!!An Error Occured During The Reading Of File With Activities For The Color Set!!!');
  end;
end;

function sortArray_INT(arrayToSort: ClassArray_type): ClassArray_type; {an implementetion of insertion sort algorithm for the sorting of integer array}
Var i, j, index : Integer;
Begin
   For i := 1 to length(arrayToSort)-1 do
   Begin
      index := arrayToSort[i];
      j := i;
      While ((j > 0) AND (arrayToSort[j-1] > index)) do
      Begin
         arrayToSort[j] := arrayToSort[j-1];
         j := j - 1;
      End;
      arrayToSort[j] := index;
   End;
   sortArray_INT:= arrayToSort;
End;

function getClasses(classArray: array of integer): ClassArray_type; {returns an array of unique classes specified in ClassFile}
var
  item: integer;
  foundClasses: ClassArray_type;
begin
  for item in classArray do
  begin
    if (getFirstItemPositionInArray_of_INT(item, foundClasses) = -1) then
    begin
      SetLength(foundClasses, length(foundClasses)+1);
      foundClasses[length(foundClasses)-1]:= item;
    end;
  end;
  getClasses:= sortArray_INT(foundClasses);
end;

function countMolsInClass(classArray: array of integer; classNumnber: integer): integer; {counts the number of molecules in a class}
var
  item: integer;
begin
  Result:=0;
  for item in classArray do
  begin
    if item=classNumnber then
       Inc(Result);
  end;
end;

procedure saveLandscape(outName: string; author: string; aGTMCl: TGTMClass;
  title, property_comment: string); {saves a Landscape into an xml file}
var
  index1, index2: integer;
  frootnode, fnode, fnode2,fnode3,fnode4: TDOMElement;
  fdoc: TXMLDocument;
  number_of_classes: integer;
  temp_var: string;
  SLlog: TStringList; // A string list to prepare outputs
begin
  frootnode:=nil;
  fnode:=nil;
  fnode2:=nil;
  SLlog:=TStringList.Create;
  //writeln('assigning the file..');
  fdoc:=TXMLDocument.Create;
  frootnode:=fdoc.CreateElement('GTM');
  frootnode.SetAttribute('tool','GTMClassTool');
  frootnode.SetAttribute('date',DateTimeToStr(Now));
  frootnode.SetAttribute('author', author);
  frootnode.SetAttribute('title',title);
  frootnode.SetAttribute('comment',property_comment);
  fdoc.AppendChild(frootnode);
  fnode:=fdoc.CreateElement('Landscape');
  fnode.SetAttribute('threshold_On_Applicability_Domain',FloatToStr(aGTMCl.MinDensityLS));
  fnode.SetAttribute('node_Threshold',FloatToStr(aGTMCl.MinRspToNode));
  fnode.SetAttribute('significance_Threshold',FloatToStr(aGTMCl.rClsThrd));
  fnode.SetAttribute('number_of_nodes',IntToStr(aGTMCl.K));
  if aGTMCl.bClassNormalize=true then fnode.SetAttribute('classNormalization','true')
  else fnode.SetAttribute('classNormalization','false');
  frootnode.AppendChild(fnode);
  number_of_classes:=aGTMCl.classSL.Count;
  for index1:=0 to number_of_classes-1 do {run through the classes}
    begin
      fnode2:=fdoc.CreateElement('Class');//This is the posterior - Keep for retro compatibility
      fnode2.SetAttribute('class',aGTMCl.classSL[index1]);
      fnode2.SetAttribute('class_ID',IntToStr(index1));
      //writeln('prior',FloatToStrF(aGTMCl.Pci[index1],ffFixed,4,4));
      fnode2.SetAttribute('prior',FloatToStrF(aGTMCl.Pci[index1],ffFixed,4,4));
      temp_var:=FloatToStrF(aGTMCl.P_ci_xk[index1][1],ffFixed,4,4);
      for index2:=2 to aGTMCl.K do {run through the nodes}
        temp_var:=temp_var+','+FloatToStrF(aGTMCl.P_ci_xk[index1,index2],ffFixed,4,4);
      fnode2.AppendChild(fdoc.CreateTextNode(temp_var));
      fnode.AppendChild(fnode2);
      fnode3:=fdoc.CreateElement('Likelihood');
      fnode3.SetAttribute('class',aGTMCl.classSL[index1]);
      fnode3.SetAttribute('class_ID',IntToStr(index1));
      fnode3.SetAttribute('prior',FloatToStrF(aGTMCl.Pci[index1],ffFixed,4,4));
      temp_var:=FloatToStrF(aGTMCl.P_xk_ci[index1][1],ffFixed,4,4);
      for index2:=2 to aGTMCl.K do {run through the nodes}
        temp_var:=temp_var+','+FloatToStrF(aGTMCl.P_xk_ci[index1,index2],ffFixed,4,4);
      fnode3.AppendChild(fdoc.CreateTextNode(temp_var));
      fnode.AppendChild(fnode3);
    end;
  fnode2:=fdoc.CreateElement('Density');
  fnode2.SetAttribute('Expected_min_density',FloatToStrF(aGTMCl.hmgDensity,ffFixed,2,2));
  fnode2.SetAttribute('Min_density',FloatToStrF(aGTMCl.minDensity,ffFixed,2,2));
  fnode2.SetAttribute('Max_density',FloatToStrF(aGTMCl.maxDensity(),ffFixed,2,2));
  temp_var:=FloatToStrF(aGTMCl.Density[1],ffFixed,4,4);
  for index1:=2 to aGTMCl.K do {run through the nodes}
       temp_var:=temp_var+','+FloatToStrF(aGTMCl.Density[index1],ffFixed,4,4);
  fnode2.AppendChild(fdoc.CreateTextNode(temp_var));
  fnode.AppendChild(fnode2);
  //Latent samples (X,Y) coordinates are located at the root
  fnode4:=fdoc.CreateElement('LatentSamples');
  fnode4.SetAttribute('K',IntToStr(aGTMCl.K));
  PrintMat(aGTMCl.matX,1,aGTMCl.K,1,2,SLlog);
  fnode4.AppendChild(fdoc.CreateTextNode(SLlog.Text));
  frootnode.AppendChild(fnode4);
  WriteXMLFile(fdoc, outName);
  FreeAndNil(SLlog);
  FreeAndNil(fdoc);
end;

function readLandscape(fileName: string): XMLData; {reads a previously saved Landscape from an xml file}
var
  fnode, fnode2: TDOMElement;
  fdoc: TXMLDocument;
  node: TDOMNodeList;
  index1, index2: integer;
  XML: XMLData;
  temp_resp_array: TStringList;
begin
  { create xml object and load xml file }
  fdoc:=TXMLDocument.Create;
  ReadXMLFile(fdoc,fileName);
  { reading the attributes for the Landscape node }
  node:=fdoc.DocumentElement.GetElementsByTagName('Landscape');
  fnode:=(node.Item[0] as TDOMElement);
  XML.MinRespAD:=StrToFloat(fnode.GetAttribute('threshold_On_Applicability_Domain'));
  XML.node_number:= StrToInt(fnode.GetAttribute('number_of_nodes'));
  XML.MinRespLS:=StrToFloat(fnode.GetAttribute('node_Threshold'));
  if fnode.GetAttribute('classNormalization')='true' then XML.classNormalization:=true
  else if fnode.GetAttribute('classNormalization')='false' then XML.classNormalization:=false;
  { finding nodes Class which contain probabilities }
  node:=fdoc.DocumentElement.GetElementsByTagName('Class');
  writeln('Number of classes is ', node.Count);
  SetLength(XML.classesList, node.Count);
  SetLength(XML.P_ci_xk, node.Count);
  for index1:=0 to node.Count-1 do {run through the classes}
  begin
    SetLength(XML.P_ci_xk[index1], XML.node_number);
    fnode2:=(node.Item[index1] as TDOMElement);
    XML.classesList[index1]:=StrToInt(fnode2.GetAttribute('class'));
    temp_resp_array:=TStringList.create;
    temp_resp_array.CommaText:=fnode2.FirstChild.NodeValue;
    for index2:=0 to XML.node_number-1 do {run through the nodes}
    begin
      XML.P_ci_xk[index1][index2]:= StrToFloat(temp_resp_array[index2]);
    end;
  end;
  fdoc.Free;
  readLandscape:= XML;
end;

procedure readLandscape(fileName: string; var aGTMCl: TGTMClass);
var
  fnode, fnode2: TDOMElement;
  fdoc: TXMLDocument;
  node: TDOMNodeList;
  index1, index2: integer;
  nNode: integer;
  temp_resp_array: TStringList;
  ClsNm: string;
  ClsId: integer;
  SLlog: TStringList; // String list for input interpretation
  dx,dy: double; //temporary double storage
  stmp: string;
begin
  temp_resp_array:=TStringList.create;
  SLlog:= TStringList.Create;
  { create xml object and load xml file }
  //fdoc:=TXMLDocument.Create;
  ReadXMLFile(fdoc,fileName);
  { reading the attributes for the Landscape node }
  node:=fdoc.DocumentElement.GetElementsByTagName('Landscape');
  fnode:=(node.Item[0] as TDOMElement);
  nNode:= StrToInt(fnode.GetAttribute('number_of_nodes'));
  if aGTMCl.K<>nNode then
    begin
      if aGTMCl.K=0 then
      begin
        aGTMCl.K:=nNode; // The aGTMReg will initialize partially based on landscape information
        aGTMCl.DoInitialize();
      end else
      begin
        raise Exception.Create('ERROR: reading landscape file. Inconsistent number of nodes between landscape and manifold');
        halt;
      end;
    end;
  aGTMCl.MinRspToNode:=StrToFloat(fnode.GetAttribute('threshold_On_Applicability_Domain'));
  aGTMCl.MinDensityLS:=StrToFloat(fnode.GetAttribute('node_Threshold'));
  aGTMCl.rClsThrd:=StrToFloat(fnode.GetAttribute('significance_Threshold'));
  if fnode.GetAttribute('classNormalization')='true' then aGTMCl.bClassNormalize:=true
  else if fnode.GetAttribute('classNormalization')='false' then aGTMCl.bClassNormalize:=false;
  { finding nodes Class which contain probabilities }
  node:=fdoc.DocumentElement.GetElementsByTagName('Class');
  //writeln('Number of classes is ', node.Count);
  aGTMCl.SetSizePrMatrix(node.Count-1);
  for index1:=0 to node.Count-1 do {run through the classes}
  begin
    fnode2:=(node.Item[index1] as TDOMElement);
    ClsNm:=fnode2.GetAttribute('class');
    ClsId:=StrToInt(fnode2.GetAttribute('class_ID'));
    if (ClsNm) <> cOutOfAD then
    begin
      ClsId:=aGTMCl.AddToClassSL(ClsNm);
    end;
    aGTMCl.Pci[ClsId]:=StrToFloat(fnode2.GetAttribute('prior'));
    temp_resp_array.Clear;
    temp_resp_array.CommaText:=fnode2.FirstChild.NodeValue;
    for index2:=0 to temp_resp_array.Count-1 do {run through the nodes}
      aGTMCl.P_ci_xk[ClsId,index2+1]:= StrToFloat(temp_resp_array[index2]);
  end;

  node:=fdoc.DocumentElement.GetElementsByTagName('Likelihood');
  if (aGTMCl.nClass<>node.Count-1) then
  begin
    writeln('ERROR: Inconsistent number of likelihood with number of classes. Your model file is likely to be corrupted.');
    halt;
  end;
  for index1:=0 to node.Count-1 do {run through the classes}
  begin
    fnode2:=(node.Item[index1] as TDOMElement);
    ClsNm:=fnode2.GetAttribute('class');
    ClsId:=StrToInt(fnode2.GetAttribute('class_ID'));
    temp_resp_array.Clear;
    temp_resp_array.CommaText:=fnode2.FirstChild.NodeValue;
    for index2:=0 to temp_resp_array.Count-1 do {run through the nodes}
      aGTMCl.P_xk_ci[ClsId,index2+1]:= StrToFloat(temp_resp_array[index2]);
  end;

  node:=fdoc.DocumentElement.GetElementsByTagName('LatentSamples');
  if node<>nil then
  begin
    SLlog.Clear;
    SLLog.Text:=(node.Item[0] as TDOMElement).FirstChild.NodeValue;
    for index1:=1 to aGTMCl.K do
    begin
      try
      stmp:=IntTostr(Length(aGTMCl.matX));
      dx:=StrToFloat(ExtractWord(1,SLlog[index1-1],[',']));
      dy:=StrToFloat(ExtractWord(2,SLlog[index1-1],[',']));;
      aGTMCl.matX[index1,1]:=dx;
      aGTMCl.matX[index1,2]:=dy;
      except
        Writeln('ERROR readLandscape. Impossible to interpret coordinates of node '+IntToStr(index1));
        halt(1);
      end;
    end;
  end;

  aGTMCl.bFinalize:=True;
  FreeAndNil(SLlog);
  FreeAndNil(temp_resp_array);
  FreeAndNil(fdoc);
end;

procedure writeOut(outName: string; array_of_lines: array of string); {writes out the results of prediction}
var
  f: textfile;
  line: string;
  item: integer;
  index1, index2: integer;
begin
  assignfile(f, outName);
  rewrite(f);
  for line in array_of_lines do {run through molecules}
  begin
    writeln(f, line);
  end;
  close(f);
end;

function maxClasses(vector: array of double; classes: array of integer): integer; {finds classes with the maximal probability;}
var
  max_value: double;
  temp_val: double;
  index: integer;
begin
  Result:=-1;
  max_value:=0.0;
  for temp_val in vector do
  begin
    if temp_val>max_value then
       max_value:=SimpleRoundTo(temp_val, -2);
  end;
  for index:=0 to length(vector)-2 do //the last item is for out_of_AD and it will be checked after
  begin
    if SimpleRoundTo(vector[index], -2)=max_value then
       Result:= classes[index];
  end;
  if vector[length(vector)-1]>max_value then Result:=-1;
end;

function IsNullOrWhiteSpace(s: string): Boolean;
begin
  s:=Trim(s);
  if (s=EmptyStr) then
    Result:=True
  else
    Result:=False;
end;

procedure TrainLandscape(aGTMClass: TGTMClass; trRspFileNme, trPrpFileNme,
  sOutFileName, sAuthor, sTitle, sComment: string; SLlog: TStrings);
var
  nNodes: integer;
  StreamRsp, StreamPrp: TFileReader;
  SLout: TStringList;//Short output files as TStringList
  sl1, sl2: string; //temporary strings
  ii, jj, kk: integer; //ii: words in stringlist; jj: lines; kk: node index
  SLRspM: TStringList; // String list of responsiblities of molecule
  SLRspN: TStringList; // String list tuple node:responsibility
  dResVal: double; //a responsibility value
  vResMol: TVector; //Vector of responsibilities for a molecule
  sprp: string; // a property value
  ClsIdx: integer; // class id
  sout: string;//output string
  aLandscapeXYZ: TMatrix;//A landscape in XYZ format
  aDensityXYZ: TMatrix;//A density in XYZ format
begin
  nNodes := aGTMClass.K;
  DimVector(vResMol, aGTMClass.K);//Vector of responsibilities for a molecule, 1-indexed
  SLlog.Add('Begin to read responsibilities.');
  { reading the responsibility file }
  try  //Use streams to deal with potentially very large amount of data
    StreamRsp := TFileReader.Create(trRspFileNme, fmOpenRead);
    StreamPrp := TFileReader.Create(trPrpFileNme, fmOpenRead);
    try
      StreamRsp.Reset;
      StreamPrp.Reset;
      //Prepare to read responsibilies and properties
      SLRspM := TStringList.Create;
      SLRspN := TStringList.Create;
      SLRspM.Delimiter := ' ';
      SLRspM.StrictDelimiter := False;
      SLRspN.Delimiter := ':';
      SLRspN.StrictDelimiter := True;
      sl2 := StreamPrp.ReadLine;
      sComment := sl2;
      SLlog.Add('Property file comment line: '+sComment);
      while not StreamRsp.EOF do
      begin
        sl1 := StreamRsp.ReadLine; //Read one line of responsibilities
        sl2 := StreamPrp.ReadLine; //Read one line of properties
        if (sl1 <> '') and (sl2 <> '') then
        begin
          //Interpret responsibilities text line
          sprp := sl2;//Get the associated property
          SLRspM.DelimitedText := sl1;
          //Check the integrity of the responsibility file
          SLRspN.DelimitedText := SLRspM.Strings[SLRspM.Count - 1];
          if (nNodes <> 0) and (nNodes <> StrToInt(SLRspN[0])) then
          begin
            raise Exception.Create('ERROR TrainLandscape: Unexpected number of nodes reading training file '
              + trRspFileNme);
            halt;
          end;
          for kk := 0 to nNodes do
            vResMol[kk] := 0; //Reset the array of responsibilities
          for ii := 1 to SLRspM.Count - 1 do
          begin
            SLRspN.DelimitedText := SLRspM[ii];
            kk := StrToInt(SLRspN[0]);
            dResVal := StrToFloat(SLRspN[1]);
            vResMol[kk] := dResVal;
          end;
          aGTMClass.AddMolecule(vResMol,sprp,ClsIdx);//Add molecule to landscape
        end;
      end;
      FreeAndNil(SLRspM);
      FreeAndNil(SLRspN);
      StreamRsp.Close;
      StreamPrp.Close;
    except
      raise Exception.Create('ERROR: reading responsibility/property file while computing landscape.');
    end;
  finally
    FreeAndNil(StreamRsp);
    FreeAndNil(StreamPrp);
  end; //End of Landscape computing
  SLlog.Add('Number of molecules processed '+IntToStr(aGTMClass.nMol0));
  SLlog.Add('Number of molecules used for landscape '+IntToStr(aGTMClass.nMol1));
  SLlog.Add('--------------------------------------');
  //Finalize Landscape
  aGTMClass.DoFinalize;
  { Saving the landscape if it was created here }
  saveLandscape(ChangeFileExt(sOutFileName,'.xml'),sAuthor,aGTMClass,sTitle,sComment);
  aDensityXYZ:=aGTMClass.GetDensityXYZ();
  aLandscapeXYZ:=aGTMClass.GetLandscapeXYZ();
  SLOut:=TStringList.Create;
  SLOut.Clear;
  PrintMat(aDensityXYZ,'Density',1,aGTMClass.K,1,3,SLout);
  SLout.SaveToFile(ChangeFileExt(sOutFileName,'Dens.mat'));
  SLlog.Add('Density column file: '+ChangeFileExt(sOutFileName,'Dens.mat'));
  SLOut.Clear;
  PrintMat(aLandscapeXYZ,'Landscape',1,aGTMClass.K,1,2+aGTMClass.nClass+1,SLout);
  SLout.SaveToFile(ChangeFileExt(sOutFileName,'LS.mat'));
  SLlog.Add('Landscape column file: '+ChangeFileExt(sOutFileName,'LS.mat'));
  FreeAndNil(SLOut);
end;

procedure TrainLandscape(aGTMClass: TGTMClass; trRspPrp: TStringList;
  sOutFileName, sAuthor, sTitle, sComment: string; SLlog: TStrings);
var
  jj: integer; // jj: lines
  ClsIdx: integer;
begin
  SLlog.Add('Processing responsibilities...');
  for jj:=0 to trRspPrp.Count-1 do
  begin
    aGTMClass.AddMolecule(trRspPrp[jj],ClsIdx);
  end;
  SLlog.Add('Number of molecules processed '+IntToStr(aGTMClass.nMol0));
  SLlog.Add('Number of molecules used for landscape '+IntToStr(aGTMClass.nMol1));
  SLlog.Add('--------------------------------------');
  //Finalize Landscape
  aGTMClass.DoFinalize;
  { Saving the landscape if it was created here }
  SLlog.Add('Landscape saved in '+ChangeFileExt(sOutFileName,'.xml'));
  saveLandscape(ChangeFileExt(sOutFileName,'.xml'),sAuthor,aGTMClass,sTitle,sComment);
end;

procedure UseLandscape(aGTMClass: TGTMClass; teRspFileNme,
  sOutFileName: string; SLlog: TStrings);
var
  {nMol0, nMol1, }nNodes: integer;
  StreamRsp: TFileReader;
  FSOut: TFileStream;
  sl1, sl2: string; //temporary strings
  ii, jj, kk: integer; //ii: words in stringlist; jj: lines; kk: node index
  SLRspM: TStringList; // String list of responsiblities of molecule
  SLRspN: TStringList; // String list tuple node:responsibility
  bInAD: boolean; //In or out of applicability domain
  dResVal: double; //a responsibility value
  vResMol: TVector; //Vector of responsibilities for a molecule
  Pci: TVector;// Predicted classes with probabilities
  sout: string;//output string
   aLandscapeXYZ: TMatrix;//A landscape in XYZ format
  aDensityXYZ: TMatrix;//A density in XYZ format
  index1: integer;
begin
  try
    StreamRsp := TFileReader.Create(teRspFileNme);
    StreamRsp.Reset;
    if FileExists(ChangeFileExt(sOutFileName,'.tsv')) then
    begin
      SLlog.Add('WARNING: File '+ChangeFileExt(sOutFileName,'.tsv')+' is overwritten.');
    end;
    FSOut := TFileStream.Create(ChangeFileExt(sOutFileName,'.tsv'), fmCreate);
    FSOut.Size := 0;
    nNodes := aGTMClass.K;
    SetLength(vResMol, aGTMClass.K + 1);//Array of responsibilities for a molecule, 1-indexed
    //
    sout := 'ID';
    for index1:=1 to aGTMClass.nClass do {run through the classes}
    begin
       sout := sout+#9+'Class_'+aGTMClass.classSL[index1]+#9+'Pr('+aGTMClass.classSL[index1]+')';
    end;
    sout := sout+#9+'Class_'+aGTMClass.classSL[0]+#9+'Pr('+aGTMClass.classSL[0]+')'+LineEnding;
    FSOut.Write(sout[1],length(sout));//WriteAnsiString(sout+LineEnding);
    //
    try
      //Prepare to read responsibilies and properties
      SLRspM := TStringList.Create;
      SLRspN := TStringList.Create;
      SLRspM.Delimiter := ' ';
      SLRspM.StrictDelimiter := False;
      SLRspN.Delimiter := ':';
      SLRspN.StrictDelimiter := True;
      //nMol0:=0; //Molecules out of AD
      //nMol1:=0; //Molecules inside AD
      jj:=0; //Count lines
      while not StreamRsp.EOF do
      begin
        Inc(jj);//Count lines
        sl1 := StreamRsp.ReadLine; //Read one line of responsibilities
        if (sl1 <> '') then
        begin
          SLRspM.DelimitedText := sl1;
          //Check the integrity of the responsibility file
          SLRspN.DelimitedText := SLRspM.Strings[SLRspM.Count - 1];
          if (nNodes <> 0) and (nNodes <> StrToInt(SLRspN[0])) then
          begin
            raise Exception.Create('ERROR UseLandscape: Unexpected number of nodes reading test file '
              + teRspFileNme);
            halt;
          end;
          for kk:=0 to aGTMClass.K do vResMol[kk]:=0;
          bInAD:=False;
          for ii:=1 to SLRspM.Count-1 do
          begin
            SLRspN.DelimitedText:=SLRspM[ii];
            kk:=StrToInt(SLRspN[0]);
            dResVal:=StrToFloat(SLRspN[1]);
            vResMol[kk]:=dResVal;
          end;
          aGTMClass.PredMol(vResMol,Pci,bInAD);
          sout := IntToStr(aGTMClass.nMol0);
          for index1:=1 to aGTMClass.nClass do
            sout := sout + #9 + aGTMClass.classSL[index1] + #9 + FloatToStrF(Pci[index1],ffFixed,4,4);
          sout := sout +#9+'0'+#9+FloatToStrF(Pci[0],ffFixed,4,4)+LineEnding;
          FSOut.Write(sout[1],length(sout));//AnsiString(sout+LineEnding);
          if (aGTMClass.nMol0 mod 5000=0) then
          begin
            SLlog.Add('Line '+IntToStr(aGTMClass.nMol0));
          end;
        end;
      end;
      FreeAndNil(SLRspM);
      FreeAndNil(SLRspN);
    except
      raise Exception.Create('ERROR: computing prediction using the landscape for the test set');
      halt;
    end;
  finally
    FreeAndNil(StreamRsp);
    FreeAndNil(FSOut);
  end;
  SLlog.Add('--------------------------------------');
  SLlog.Add('Number of molecules processed: '+IntToStr(aGTMClass.nMol0));
  SLlog.Add('Number of molecules in AD: '+IntToStr(aGTMClass.nMol1));
  SLlog.Add('Number of molecules out AD: '+IntToStr(aGTMClass.nMol0-aGTMClass.nMol1));
  SLlog.Add('--------------------------------------');
end;

procedure UseLandscape(aGTMClass: TGTMClass; teRsp: TStringList;
  sOutFileName: string; aClsStat: TClsStats; SLlog: TStrings); // Procedure to manage class statistics.
var
  {nMol0, nMol1, }nNodes: integer;
  StreamRsp: TFileReader;
  FSOut: TFileStream;
  sl1, sl2: string; //temporary strings
  ii, jj, kk, cc: integer; //ii: words in stringlist; jj: lines; kk: node index
  SLRspM: TStringList; // String list of responsiblities of molecule
  SLRspN: TStringList; // String list tuple node:responsibility
  bInAD: boolean; //In or out of applicability domain
  dResVal: double; //a responsibility value
  vResMol: TVector; //Array of responsibilities for a molecule
  PCi: TVector; // a prediction vector of probabilities
  iprd: integer; // index of predicted class
  pprd: double; // associated probability of predicted class
  rprd: double; //ratio of probability
  sexp: string; // experimental class value
  iexp: integer; // experimental class index
  sout: string;//output string
begin
  vResMol:=nil;
  if FileExists(ChangeFileExt(sOutFileName,'.tsv')) then
  begin
    SLlog.Add('WARNING: File '+ChangeFileExt(sOutFileName,'.tsv')+' is overwritten.');
  end;
  try
    aClsStat.InitConfusion(aGTMClass.nClass);
    FSOut := TFileStream.Create(ChangeFileExt(sOutFileName,'.tsv'), fmCreate);
    FSOut.Size := 0;
    nNodes := aGTMClass.K;
    DimVector(vResMol,aGTMClass.K);
    //
    sout := 'ID';
    for ii:=1 to aGTMClass.nClass do {run through the classes}
    begin
       sout := sout+#9+'Class_'+aGTMClass.classSL[ii]+#9+'Pr('+aGTMClass.classSL[ii]+')';
    end;
    sout := sout+#9+'Class_'+aGTMClass.classSL[0]+#9+'Pr('+aGTMClass.classSL[0]+')'+LineEnding;
    FSOut.Write(sout[1],length(sout));//WriteAnsiString(sout+LineEnding);
    //
    try
      //Prepare to read responsibilies and properties
      SLRspM := TStringList.Create;
      SLRspN := TStringList.Create;
      SLRspM.Delimiter := ' ';
      SLRspM.StrictDelimiter := False;
      SLRspN.Delimiter := ':';
      SLRspN.StrictDelimiter := True;
      //nMol0:=0; //Molecules out of AD
      //nMol1:=0; //Molecules inside AD
      for jj:=0 to teRsp.Count-1 do
      begin
        sl1:=teRsp[jj];
        sexp := ExtractWord(1,sl1,[' ']); //Read one line of responsibilities - class as 1st column
        iexp:=aGTMClass.classSL.IndexOf(sexp);
        if (sl1 <> '') then
        begin
          SLRspM.DelimitedText := sl1;
          //Check the integrity of the responsibility file
          SLRspN.DelimitedText := SLRspM.Strings[SLRspM.Count - 1];
          if (nNodes <> 0) and (nNodes <> StrToInt(SLRspN[0])) then
          begin
            raise Exception.Create('ERROR UseLandscape: Unexpected number of nodes in line: '
              + sl1);
            halt;
          end;
          for kk:=0 to aGTMClass.K do vResMol[kk]:=0;
          bInAD:=False;
          for ii:=1 to SLRspM.Count-1 do
          begin
            SLRspN.DelimitedText:=SLRspM[ii];
            kk:=StrToInt(SLRspN[0]);
            dResVal:=StrToFloat(SLRspN[1]);
            vResMol[kk]:=dResVal;
          end;
          aGTMClass.PredMol(vResMol,PCi,bInAD);
          iprd:=0;
          pprd:=PCi[iprd];
          for cc:=Low(PCi) to High(PCi) do
            if pprd<PCi[cc] then
            begin
              pprd:=PCi[cc];
              iprd:=cc;
            end;
          //
          {rprd:=NaN;
          if iprd>0 then //if not out of AD test if major class is significant
          begin
            for cc:=1 to High(PCi) do
            begin
              if (cc<>iprd) then rprd:=PCi[cc]/pprd;//Can be NaN
              if not IsNan(rprd) then
                if (rprd>rClsThr) then //ambiguous class prediction -> out of AD
                begin
                  iprd:=0;//Put to out of AD class
                end;
            end;
            if (iprd>0) then
            begin
              aClsStat.Confusion[iexp-1,iprd-1]:=aClsStat.Confusion[iexp-1,iprd-1]+1; //Fill confusion matrix (0 based index)
            end;
          end;}
          if bInAD then
          begin
            aClsStat.Confusion[iexp-1,iprd-1]:=aClsStat.Confusion[iexp-1,iprd-1]+1;
          end;
          //
          sout := IntToStr(aGTMClass.nMol0);
          for ii:=1 to aGTMClass.nClass do
            sout := sout + #9 + aGTMClass.classSL[ii] + #9 + FloatToStrF(Pci[ii],ffFixed,4,4);
          sout := sout +#9+'0'+#9+FloatToStrF(Pci[0],ffFixed,4,4)+LineEnding;
          FSOut.Write(sout[1],length(sout));//AnsiString(sout+LineEnding);
        end;
      end;
      FreeAndNil(SLRspM);
      FreeAndNil(SLRspN);
    except
      raise Exception.Create('ERROR: computing prediction using the landscape for the test set');
      halt;
    end;
  finally
    FreeAndNil(FSOut);
  end;
  SLlog.Add('--------------------------------------');
  SLlog.Add('Number of molecules processed: '+IntToStr(aGTMClass.nMol0));
  SLlog.Add('Number of molecules in AD: '+IntToStr(aGTMClass.nMol1));
  SLlog.Add('Number of molecules out AD: '+IntToStr(aGTMClass.nMol0-aGTMClass.nMol1));
  SLlog.Add('--------------------------------------');
end;

end.
