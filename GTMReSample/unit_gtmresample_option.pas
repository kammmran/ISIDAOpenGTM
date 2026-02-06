unit unit_GTMReSample_option;

{$mode objfpc}{$H+}
//Macro so that at compile time, if GUI is used, writeln will store
//strings into a SLog TStringList and if not, it is directed to stdout.
{$MACRO ON}
//{$DEFINE WRITELN:={$IFDEF GUI}SLog.Add{$ELSE}writeln{$ENDIF}}

interface

uses
  Classes, SysUtils;//, utypes, ISIDA_DESCRIPTOR;//, ueigen_ops;

type

{ TGTMReSample_option }

TGTMReSample_option = class(TObject)
private
  finput, foutput, fmodel: string;
  fnewK, fheight, fwidth: integer;
  fb3D, fbRmat: boolean; //3D and Rmat output yes/no
public
  property input:string read finput write finput;
  property output:string read foutput write foutput;
  property model:string read fmodel write fmodel;
  property height:integer read fheight write fheight;
  property width:integer read fwidth write fwidth;
  property newK: integer read fnewK write fnewK;
  property b3D: Boolean read fb3D write fb3D;
  property bRmat: Boolean read fbRmat write fbRmat;
  constructor Create;
  destructor Destroy; override;
  procedure Welcome();
  procedure DisplayParameters();
end;

implementation

{ TGTMReSample_option }

constructor TGTMReSample_option.Create;
begin
  finput:='';
  foutput:='';
  fmodel:='';
  fheight:=0;
  fwidth:=0;
  fnewK:=0;
  fb3D:=False;
  fbRmat:=False;
end;

destructor TGTMReSample_option.Destroy;
begin
  inherited Destroy;
end;

procedure TGTMReSample_option.Welcome();
begin
  WRITELN('*********************************');
  WRITELN('*                               *');
  WRITELN('* ISIDA/GTMReSample             *');
  WRITELN('*                               *');
  WRITELN('* G. Marcou                     *');
  WRITELN('* University od Strasbourg, 2018*');
  WRITELN('*                               *');
  WRITELN('*********************************');
end;

procedure TGTMReSample_option.DisplayParameters();
begin
  if (finput<>'') then WRITELN('Input file: '+finput);
  WRITELN('Model file: '+fmodel);
  WRITELN('Outputs base name: '+foutput);
  if fwidth<>0 then
    WRITELN('New width: '+IntToStr(fwidth));
  if fheight<>0 then
    WRITELN('New height: '+IntToStr(fheight));
  if fnewK<>0 then
    WRITELN('New resoution: '+IntToStr(fnewK));
  if (fb3D) then
    WRITELN('Output 3D files');
  if (fbRmat) then
    WRITELN('Output responsability matrices');
end;

end.

