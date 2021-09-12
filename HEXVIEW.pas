PROGRAM HexViewer;

USES
     Objects, Drivers, Views, Editors, Menus, Dialogs, App,             { Standard GFV units }
     FVConsts, Gadgets, MsgBox, StdDlg, SysUtils;

CONST cmAppToolbar = 1000;

TYPE
   PHexView = ^THexView;

   THexView = OBJECT (TApplication)
        ClipboardWindow: PEditWindow;
        OutputWindow : PEditWindow;
        Clock: PClockView;
        Heap: PHeapView;
      CONSTRUCTOR Init;
      PROCEDURE Idle; Virtual;
      PROCEDURE HandleEvent(var Event : TEvent); Virtual;
      PROCEDURE InitMenuBar; Virtual;
      PROCEDURE InitDeskTop; Virtual;
      PROCEDURE InitStatusLine; Virtual;
      PROCEDURE Convert(FileName:String);
      PROCEDURE SaveAll;
      PROCEDURE CloseAll;
      PROCEDURE ShowAboutBox;
      PROCEDURE NewEditWindow;
      PROCEDURE OpenFile;
    End;

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                           THexView OBJECT METHODS                          }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}

CONSTRUCTOR THexView.Init;
VAR R: TRect;
BEGIN
  EditorDialog := @StdEditorDialog;
  Inherited Init;

  GetExtent(R);
  R.A.X := R.B.X - 9; R.B.Y := R.A.Y + 1;
  Clock := New(PClockView, Init(R));
  Insert(Clock);

  GetExtent(R);
  ClipboardWindow := New(PEditWindow, Init(R, '', wnNoNumber));
  if ValidView(ClipboardWindow) <> nil then
  begin
    ClipboardWindow^.Hide;
    ClipboardWindow^.Editor^.CanUndo := False;
    InsertWindow(ClipboardWindow);
    Clipboard := ClipboardWindow^.Editor;
  end;
END;

procedure THexView.Idle;

function IsTileable(P: PView): Boolean; far;
begin
  IsTileable := (P^.Options and ofTileable <> 0) and
    (P^.State and sfVisible <> 0);
end;

begin
  inherited Idle;

  Clock^.Update;
  Heap^.Update;

  if Desktop^.FirstThat(@IsTileable) <> nil then
    EnableCommands([cmTile, cmCascade])
  else
    DisableCommands([cmTile, cmCascade]);
end;

PROCEDURE THexView.HandleEvent(var Event : TEvent);
BEGIN
   Inherited HandleEvent(Event);                      { Call ancestor }
   If (Event.What = evCommand) Then Begin
     Case Event.Command Of
       cmClipBoard:
         begin
           ClipboardWindow^.Select;
           ClipboardWindow^.Show;
         end;
       cmNew     : NewEditWindow;
       cmOpen    : OpenFile;
       {cmSaveAll : SaveAll;}
       cmCloseAll: CloseAll;
       cmAbout: ShowAboutBox;
       Else Exit;                                     { Unhandled exit }
     End;
   End;
   ClearEvent(Event);
END;

{--THexView------------------------------------------------------------------}
{  InitMenuBar                                                              }
{---------------------------------------------------------------------------}
PROCEDURE THexView.InitMenuBar;
VAR R: TRect;
BEGIN
   GetExtent(R);                                      { Get view extents }
   R.B.Y := R.A.Y + 1;                                { One line high  }
   MenuBar := New(PMenuBar, Init(R, NewMenu(
    NewSubMenu('~F~ile', 0, NewMenu(
      StdFileMenuItems(Nil)),                         { Standard file menu }
    NewSubMenu('~E~dit', 0, NewMenu(
      StdEditMenuItems(
      NewLine(
      NewItem('~V~iew Clipboard', '', kbNoKey, cmClipboard, hcNoContext,
      nil)))),                 { Standard edit menu plus view clipboard}
    {NewSubMenu('~P~roject', 0, NewMenu(
      NewItem('~A~scii Chart','',kbNoKey,cmAscii,hcNoContext,
      NewItem('~C~ompile','F9',kbF9,cmCompile,hcNoContext,
      NewItem('Window ~2~','',kbNoKey,cmWindow2,hcNoContext,
      NewItem('Window ~3~','',kbNoKey,cmWindow3,hcNoContext,
      NewItem('~T~imed Box','',kbNoKey,cmTimedBox,hcNoContext,
      NewItem('Close Window 1','',kbNoKey,cmCloseWindow1,hcNoContext,
      NewItem('Close Window 2','',kbNoKey,cmCloseWindow2,hcNoContext,
      NewItem('Close Window 3','',kbNoKey,cmCloseWindow3,hcNoContext,
      Nil))))))))),}
    NewSubMenu('~W~indow', 0, NewMenu(
      StdWindowMenuItems(Nil)),        { Standard window  menu }
    NewSubMenu('~H~elp', hcNoContext, NewMenu(
      NewItem('~A~bout...','',kbNoKey,cmAbout,hcNoContext,
      nil)),
    nil)))) //end NewSubMenus
   ))); //end MenuBar
END;

{--THexView------------------------------------------------------------------}
{  InitDesktop                                                              }
{---------------------------------------------------------------------------}
PROCEDURE THexView.InitDesktop;
VAR R: TRect; {ToolBar: PToolBar;}
BEGIN
   GetExtent(R);                                      { Get app extents }
   Inc(R.A.Y);               { Adjust top down }
   Dec(R.B.Y);            { Adjust bottom up }
   Desktop := New(PDeskTop, Init(R));
END;

procedure THexView.InitStatusLine;
var
   R: TRect;
begin
  GetExtent(R);
  R.A.Y := R.B.Y - 1;
  R.B.X := R.B.X - 12;
  New(StatusLine,
    Init(R,
      NewStatusDef(0, $EFFF,
        NewStatusKey('~F3~ Open', kbF3, cmOpen,
        {NewStatusKey('~F4~ New', kbF4, cmNew,
        NewStatusKey('~F9~ Compile', kbF9, cmCompile,}
        NewStatusKey('~Alt+F3~ Close', kbAltF3, cmClose,
        NewStatusKey('HEXVIEW 0.01', kbNoKey, cmAbout,
        StdStatusKeys(nil
        )))),nil
      )
    )
  );

  GetExtent(R);
  R.A.X := R.B.X - 12; R.A.Y := R.B.Y - 1;
  Heap := New(PHeapView, Init(R));
  Insert(Heap);
end;

PROCEDURE THexView.Convert(FileName:String);

    PROCEDURE HexDump(FN:String); 
    var
      F: File of Byte;
      T: Text;
      B: Byte;
      Ofs: Longint;
      S: String;
      I, C: Integer;
      ASCII:array [0..15] of Char;

    begin
      Assign(F, FN);
      Reset(F);

      Assign(T, FN+'.TXT');
      Rewrite(T);

      Ofs:=0;
      while not EOF(F) do
      begin
        Write(T, IntToHex(Ofs, 8));
        Write(T, '    ');

        for I:=0 to 15 do
        begin
          if EOF(F) then
          begin
            C:=I-1;
            break;
          end
          else
            Read(F,B);

          Write(T, IntToHex(B, 2));
          Write(T, '  ');
          if (B>=32) and (B<127) then
            ASCII[I]:=Chr(B)
          else
            ASCII[I]:='.';
          C:=I;
        end;
        for I:=C to 15 do
          Write(T,'    ');

        for I:=0 to C do
        begin
          Write(T,ASCII[I]);
        end;
        WriteLn(T);
        Ofs:=Ofs+16;
      end;

      Close(F);
      Close(T);
    end;

var
  T: Text;
  R: TRect;

begin
  if FileName <> '' then
  begin
    HexDump(FileName);

    R.Assign(0, 0, 110, 25);
    OutputWindow:=New(PEditWindow, Init(R, FileName+'.TXT', wnNoNumber));
    InsertWindow(OutputWindow);
    {OutputWindow^.Show;}
    DeleteFile(FileName+'.TXT');
    {OutputWindow^.Title:=@FileName;}
  end;
end;

PROCEDURE THexView.ShowAboutBox;
begin
  MessageBox(#3'HEXVIEW 0.01'#13+
    #3'Developed by Boo Khan Ming'#13+
    #3'(Jan 25, 2021)'#13+
    #3'Derived from HEXDUMP',
    nil, mfInformation or mfOKButton);
end;

PROCEDURE THexView.NewEditWindow;
var
  R: TRect;
begin
{
  R.Assign(0, 0, 75, 20);
  SourceWindow:=New(PEditWindow, Init(R, '', wnNoNumber));
  InsertWindow(SourceWindow);
}
end;

PROCEDURE THexView.OpenFile;
var
  R: TRect;
  FileDialog: PFileDialog;
  FileName: FNameStr;
const
  FDOptions: Word = fdOKButton or fdOpenButton;
begin
  FileName := '*.*';
  New(FileDialog, Init(FileName, 'Open file', '~F~ile name', FDOptions, 1));
  if ExecuteDialog(FileDialog, @FileName) <> cmCancel then
  begin
    {
    R.Assign(0, 0, 75, 20);
    SourceWindow:=New(PEditWindow, Init(R, FileName, wnNoNumber));
    InsertWindow(SourceWindow);
    }
    Convert(FileName);
  end;
end;

PROCEDURE THexView.SaveAll;

    PROCEDURE SendSave(P: PView);
    begin
      Message(P, evCommand, cmSave, nil);
    end;

begin
  Desktop^.ForEach(@SendSave);
end;

PROCEDURE THexView.CloseAll;

    PROCEDURE SendClose(P: PView);
    begin
      Message(P, evCommand, cmClose, nil);
    end;

begin
  Desktop^.ForEach(@SendClose);
end;

{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
{                             MAIN PROGRAM START                            }
{+++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++}
VAR HexView: THexView;

BEGIN
   HexView.Init;                                        { Initialize app }
   HexView.Run;                                         { Run the app }
   HexView.Done;                                        { Dispose of app }
END.
