program xGTMapTool;

{$mode objfpc}{$H+}

uses
  {$IFDEF UNIX}{$IFDEF UseCThreads}
  cthreads,
  {$ENDIF}{$ENDIF}
  Interfaces, // this includes the LCL widgetset
  Forms, uxGTMapTool, UnitProc, UcGTM, UGTMBase, ugtm_options, ISIDA_descriptor,
  utypes
  { you can add units after this };

{$R *.res}

begin
  RequireDerivedFormResource:=True;
  Application.Initialize;
  Application.CreateForm(TFGTMapTool, FGTMapTool);
  Application.Run;
end.

