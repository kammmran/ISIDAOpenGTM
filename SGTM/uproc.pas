unit uProc;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils,utypes;

procedure Welcome();
procedure PrintParameters(soutput:string; app, aK,aM: integer; aw,al: double; SLaVw, SLinputs: TStringList);

implementation

procedure Welcome();
begin
  Writeln('******************************************************************');
  Writeln('*                                                                *');
  Writeln('*                      ISIDA/Stargate-GTM                        *');
  Writeln('*                                                                *');
  Writeln('* G. Marcou                       University of Strasbourg, 2020 *');
  Writeln('******************************************************************');
end;

procedure PrintParameters(soutput:string; app, aK, aM: integer; aw, al: double; SLaVw,
  SLinputs: TStringList);
var
  ii: integer;
begin
  Writeln('Inputs          : ');
  for ii:=0 to SLinputs.Count-1 do
  Writeln('                 '+SLinputs[ii]);
  Writeln('Outputs: '+soutput);
  Write('Pre-processing  : ');
  case app of
    0: writeln('no pre-processing');
    1: writeln('standardize');
    2: writeln('center');
    3: writeln('normalize');
    4: writeln('normalize+center');
    else writeln('unknown pre-processing');
  end;
  Writeln('Number of traits: ',aM);
  Writeln('Number of nodes : ',aK);
  Writeln('RBF width       : ', aw);
  Writeln('Regularization  : ', al);
  Writeln('Weights         : ');
  for ii:=0 to SLaVw.Count-1 do
    Writeln('                 map['+IntToStr(ii)+']='+SLaVw[ii]);
  Writeln('Start calculations...');
end;

end.

