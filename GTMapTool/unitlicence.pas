unit UnitLicence;

{$mode objfpc}{$H+}

interface

uses
  {$IFDEF GUI}
  Dialogs,
  {$ENDIF}
  Classes, SysUtils, strutils, dateutils;

procedure CheckLicence(sLicFile: string);
procedure CheckLicence();
function StrToDateH(sLicFile: string): TDateTime;
procedure CreateLicence(SLicFile: String; dstart, dend: TDateTime; name: String);

implementation

procedure CheckLicence(sLicFile: string);
var
  slLic: TStringList; //Licence file handle
  sDate: string; // the date for licence checking
  bLicIsValid,bNoLic: boolean;
  Today,LicDay: TDateTime;

begin
    sDate:=DateToStr(Date);
    bLicIsValid:=False;
    bNoLic:=False;
    slLic:=TStringList.Create;
    Today:=Date;
    If FileExists(sLicFile) then
    begin
      slLic.LoadFromFile(sLicFile);
      sDate:=slLic[11];//slLic[9];
      try
        LicDay:=StrToDateH(sDate);//StrToDate(sDate);
        if CompareDate(LicDay,StrToDate(slLic[7])) <>0 then
        begin
          {$IFDEF GUI}
          ShowMessage('Error inconsistent licence file. Licence file is: '+sLicFile);
          {$ELSE}
          writeln('Error inconsistent licence file. Licence file is: '+sLicFile);
          {$ENDIF}
          halt;
        end;
      except
      On E:Exception Do
      begin
        {$IFDEF GUI}
        ShowMessage('Error reading licence file. Licence file is: '+sLicFile);
        ShowMessage('Exception : '+E.Message);
        {$ELSE}
        writeln('Error reading licence file. Licence file is: '+sLicFile);
        {$ENDIF}
        halt;
      end;
      end;
      sDate:=slLic[12];//slLic[9];
      try
        LicDay:=StrToDateH(sDate);//StrToDate(sDate);
        if CompareDate(LicDay,StrToDate(slLic[9])) <>0 then
        begin
          {$IFDEF GUI}
          ShowMessage('Error inconsistent licence file. Licence file is: '+sLicFile);
          {$ELSE}
          writeln('Error inconsistent licence file. Licence file is: '+sLicFile);
          {$ENDIF}
          halt;
        end;
      except
      On Exception Do
      begin
        {$IFDEF GUI}
        ShowMessage('Error reading licence file. Licence file is: '+sLicFile);
        {$ELSE}
        writeln('Error reading licence file. Licence file is: '+sLicFile);
        {$ENDIF}
        halt;
      end;
      end;
      if CompareDate(Today,LicDay)<0 then bLicIsValid:=True;
    end else bNoLic:=True;
    if bNoLic then
    begin
      {$IFDEF GUI}
      ShowMessage('Impossible to locate licence file. Licence file should be: '+sLicFile);
      {$ELSE}
      writeln('Impossible to locate licence file. Licence file should be: '+sLicFile);
      {$ENDIF}
      halt;
    end;
    if bLicIsValid=False then
    begin
      {$IFDEF GUI}
      ShowMessage('Invalid licence. Licence file is: '+sLicFile);
      {$ELSE}
      writeln('Invalid licence. Licence file is: '+sLicFile);
      {$ENDIF}
      halt;
    end else
    begin
      {$IFDEF GUI}
      ShowMessage('+++ Licence ending the: '+DateToStr(LicDay)+' +++'+sLineBreak+
      '+++'+slLic[10]+'+++');
      {$ELSE}
      writeln('+++ Licence ending the: '+DateToStr(LicDay)+' +++');
      writeln('+++'+slLic[10]+'+++');
      {$ENDIF}
    end;
    FreeAndNil(slLic);
end;

function StrToDateH(sLicFile: string): TDateTime;
var
  pyear: array [0..99] of word =  (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331, 337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397, 401, 409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463, 467, 479, 487, 491, 499, 503, 509, 521, 523, 541);
  pday: array [1..31] of word =  (547, 557, 563, 569, 571, 577, 587, 593, 599, 601, 607, 613, 617, 619, 631, 641, 643, 647, 653, 659, 661, 673, 677, 683, 691, 701, 709, 719, 727, 733, 739);
  pmonth: array [1..12] of word =  ( 743, 751, 757, 761, 769, 773, 787, 797, 809, 811, 821, 823);
  day,month,year: word;
  day0,month0,year0: word;
  product: LongWord;
  i: integer;
  bFound: Boolean;
  Today: TDateTime;
begin
  try
    product:=hex2dec(sLicFile);
  except
  On Exception Do
  begin
    {$IFDEF GUI}
    ShowMessage('Error decoding licence file key. Licence file is: '+sLicFile);
    {$ELSE}
    writeln('Error decoding licence file key. Licence file is: '+sLicFile);
    {$ENDIF}
    halt;
  end;
  end;
  //Search year
  bFound:=False;
  i:=Low(pyear);
  while (i<=High(pyear)) and (not bFound) do
  begin
    if (product mod pyear[i])=0 then
    begin
       bFound:=True;
       year:=i;
    end;
    Inc(i);
  end;
  if (not bFound) then
  begin
    {$IFDEF GUI}
    ShowMessage('Error decoding licence file date: year. Licence file is: '+sLicFile);
    {$ELSE}
    writeln('Error decoding licence file date: year. Licence file is: '+sLicFile);
    {$ENDIF}
  end;
  //Search Month
  bFound:=False;
  i:=Low(pmonth);
  while (i<=High(pmonth)) and (not bFound) do
  begin
    if (product mod pmonth[i])=0 then
    begin
       bFound:=True;
       month:=i;
    end;
    Inc(i);
  end;
  if (not bFound) then
  begin
    {$IFDEF GUI}
    ShowMessage('Error decoding licence file date: month. Licence file is: '+sLicFile);
    {$ELSE}
    writeln('Error decoding licence file date: month. Licence file is: '+sLicFile);
    {$ENDIF}
  end;
  //Search day
  bFound:=False;
  i:=Low(pday);
  while (i<=High(pday)) and (not bFound) do
  begin
    if (product mod pday[i])=0 then
    begin
       bFound:=True;
       day:=i;
    end;
    Inc(i);
  end;
  if (not bFound) then
  begin
    {$IFDEF GUI}
    ShowMessage('Error decoding licence file date: day. Licence file is: '+sLicFile);
    {$ELSE}
    writeln('Error decoding licence file date: day. Licence file is: '+sLicFile);
    {$ENDIF}
  end;
  //Convert to TDate - only the two last digit year are recorded.
  Today:=Date;
  DecodeDate(Today,year0,month0,day0);
  year:=(year0 div 100)*100+year; //Need to recover the century
  StrToDateH:=EncodeDate(year,month,day);
end;

procedure CheckLicence();
var
  sLicFile: string;
begin
    //Licence checking
    //Set the location of licence file into ISIDAGTM
    sLicFile:=GetAppConfigDir(False)+'..'+PathDelim+'ISIDAGTM';
    sLicFile:=ExpandFileName(sLicFile)+PathDelim;
    sLicFile:=sLicFile+'licence.dat';
    CheckLicence(sLicFile);
end;

procedure CreateLicence(SLicFile: String; dstart, dend: TDateTime; name: String
  );
type
  TPrime = array of longint;
var
  pyear: array [0..99] of word =  (2, 3, 5, 7, 11, 13, 17, 19, 23, 29, 31, 37, 41, 43, 47, 53, 59, 61, 67, 71, 73, 79, 83, 89, 97, 101, 103, 107, 109, 113, 127, 131, 137, 139, 149, 151, 157, 163, 167, 173, 179, 181, 191, 193, 197, 199, 211, 223, 227, 229, 233, 239, 241, 251, 257, 263, 269, 271, 277, 281, 283, 293, 307, 311, 313, 317, 331, 337, 347, 349, 353, 359, 367, 373, 379, 383, 389, 397, 401, 409, 419, 421, 431, 433, 439, 443, 449, 457, 461, 463, 467, 479, 487, 491, 499, 503, 509, 521, 523, 541);
  pday: array [1..31] of word =  (547, 557, 563, 569, 571, 577, 587, 593, 599, 601, 607, 613, 617, 619, 631, 641, 643, 647, 653, 659, 661, 673, 677, 683, 691, 701, 709, 719, 727, 733, 739);
  pmonth: array [1..12] of word =  ( 743, 751, 757, 761, 769, 773, 787, 797, 809, 811, 821, 823);
  day,month,year: word;
  product: LongWord;
  SLLic: TStringList;
begin
  SLLic:=TStringList.Create;
  SLLic.Add('********************************************');
  SLLic.Add('* University of Strasbourg                 *');
  SLLic.Add('* Laboratoire de Chemoinformatique         *');
  SLLic.Add('*                                          *');
  SLLic.Add('********************************************');
  SLLic.Add('Licensed by: Prof. Alexandre VARNEK');
  SLLic.Add('From');
  SLLic.Add(DateToStr(dstart));
  SLLic.Add('to');
  SLLic.Add(DateToStr(dend));
  SLLic.Add('Licensed to: '+name);
  DecodeDate(dstart,year,month,day);
  year:=year mod 100;
  product:=pyear[year]*pmonth[month]*pday[day];
  SLLic.Add(IntToHex(product,8));
  DecodeDate(dend,year,month,day);
  year:=year mod 100;
  product:=pyear[year]*pmonth[month]*pday[day];
  SLLic.Add(IntToHex(product,8));
  SLLic.SaveToFile(SLicFile);
  FreeAndNil(SLLic);
end;


end.

