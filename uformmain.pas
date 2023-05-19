unit uFormMain;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Forms, Controls, Graphics, Dialogs, StdCtrls, ExtCtrls,
  Buttons, ComCtrls, IniFiles, uKlasse,
  Windows, ActiveX, ShlObj;




type
  { TFormMain }

  TFormMain = class(TForm)
    BitBtn1: TBitBtn;
    BitBtn2: TBitBtn;
    ESource: TEdit;
    GroupBox1: TGroupBox;
    GroupBox2: TGroupBox;
    GroupBox3: TGroupBox;
    Label1: TLabel;
    Label10: TLabel;
    Label11: TLabel;
    Label2: TLabel;
    Label3: TLabel;
    Label4: TLabel;
    Label5: TLabel;
    Label6: TLabel;
    Label7: TLabel;
    Label8: TLabel;
    Label9: TLabel;
    ListBox1: TListBox;
    ListBox2: TListBox;
    ListBox3: TListBox;
    MemoEinsammeln: TMemo;
    MemoAusteilen: TMemo;
    OpenDialog: TOpenDialog;
    PageControl1: TPageControl;
    Panel2: TPanel;
    Panel3: TPanel;
    Panel4: TPanel;
    Panel5: TPanel;
    SBSelectFile: TSpeedButton;
    SBSelectFolder: TSpeedButton;
    SelectDirectoryDialog: TSelectDirectoryDialog;
    Splitter1: TSplitter;
    TSAusteilen: TTabSheet;
    TSEinsammeln: TTabSheet;
    procedure BitBtn1Click(Sender: TObject);
    procedure BitBtn2Click(Sender: TObject);
    procedure ESourceChange(Sender: TObject);
    procedure FormClose(Sender: TObject; var CloseAction: TCloseAction);
    procedure FormCreate(Sender: TObject);
    procedure ListBox1Click(Sender: TObject);
    procedure SBSelectFileClick(Sender: TObject);
    procedure SBSelectFolderClick(Sender: TObject);
    function  GetCfgString( Section:String; Ident:String; default:String ) : String;
    function  isFile( Ident:String ) : boolean;
    function  isDirectory( Ident:String ) : boolean;
    function  ExtractLastDir( s:String ) : String;

    procedure Austeilen;
    procedure CheckTeilnehmer( Klasse:String; ziele:TStringList );
    procedure CheckAusteilen;
    function  GetTeilnehmerFromSource( source:String ) : String;

    function  GetShortcutTarget(const ShortcutFilename: string): string;
  private
    FConfig      : TMemInifile;
    FData        : TKlassen;

    FTeilnehmer  : TStringList;   //Name der Teilnehmer
    FSourceFiles : TStringList;   //Liste der auszuteilenden Quelldateien
    FTargetSubDir: String;        //bei den Teilnehmern anzulegender Ordner, muss auch beim Einsammeln angelegt werden

    FTargets     : TStringList;
    procedure ReadClassList;
    //procedure FindFiles (aPath, aFindMask: String; aWithSub: Boolean; Attr : Longint; aResult: tStrings);
  public

  end;

var
  FormMain: TFormMain;

implementation

{$R *.lfm}
uses FileUtil, StrUtils;

{ TFormMain }

procedure TFormMain.FormCreate(Sender: TObject);
begin
 FConfig :=  TMemInifile.Create( ChangeFileExt( Application.ExeName, '.ini' ) );
 FData   := TKlassen.Create;
 BitBtn1.Enabled := false;
 MemoAusteilen.Clear;
 MemoEinsammeln.Clear;
 Label2.Caption := '';    Label4.Caption := '';   Label11.Caption := '';
 Panel3.Caption := '';    Label6.Caption := '';
 Panel4.Caption := '';    Label10.Caption := '';
 Label8.Caption := FConfig.ReadString( 'Settings', 'Einsammeln', '' );
 FTargets:= TStringList.Create;
 FTeilnehmer  := TStringList.Create;
 FSourceFiles := NIL;
 ReadClassList;
 PageControl1.ActivePageIndex:=0;
end;

procedure TFormMain.ListBox1Click(Sender: TObject);
begin
  if ListBox1.ItemIndex > -1 then begin
    FTargets.Clear;
    CheckTeilnehmer( ListBox1.Items[ ListBox1.ItemIndex ], FTargets );
  end;
  CheckAusteilen;
end;

procedure TFormMain.FormClose(Sender: TObject; var CloseAction: TCloseAction);
begin
  FreeAndNIL( FData );
  FreeAndNIL( FConfig );
end;

procedure TFormMain.CheckTeilnehmer( Klasse:String; ziele:TStringList );
var folder, target, targetDir, user, prefix, s : String;    liste:TStringList;   i:integer;
begin
  if assigned( ziele ) then begin
    Screen.Cursor := crHourGlass;
    try
      folder := Format( FConfig.ReadString( 'Settings', 'AllClasses', 'I:\' ), [Klasse] );
      prefix := FConfig.ReadString( 'Settings', 'UserNamePrefix', '' );
      liste := TStringList.Create;
      try
        //FindAllDirectories( liste, folder, false );
        FindAllFiles( liste, folder, '*.*', false );
        //Jetzt haben wir die lnk-Files. Wohin zeigen die?
        //https://www.swissdelphicenter.ch/de/showcode.php?id=970
        //https://forum.lazarus.freepascal.org/index.php?topic=1709.0

        ListBox2.Clear;
        FTeilnehmer.Clear;
        targetDir := FConfig.ReadString( 'Settings', 'TargetDir', '' );
        for i:=0 to liste.Count-1 do begin
          user := GetShortcutTarget( liste.Strings[i] );         //dem Link *.lnk folgen...
          if user <> '' then begin
            ziele.Add( Format( targetDir, [ user ] ) );
            //Teilnehmerliste aufbauen
            if StartsStr( prefix, user ) then begin
              s := Copy( user, length(prefix)+1, length(user) );
              s := ExcludeTrailingPathDelimiter( s );
              s := StringReplace( s, '$', '', [rfReplaceAll,rfIgnoreCase] );
              FTeilnehmer.Add( s );
            end else FTeilnehmer.Add( user );  //macht das Sinn?
          end;
        end;

        for i:=0 to ziele.Count-1 do
           ListBox2.AddItem( ziele.Strings[i], nil );

        ListBox3.Clear;
        for i:=0 to FTeilnehmer.Count-1 do
           ListBox3.AddItem( FTeilnehmer.Strings[i], nil );

        Panel4.Caption := IntToStr( ziele.Count ) + ' Elemente';
      finally
        FreeandNIL( liste );
      end;
    finally
      Screen.Cursor := crDefault;
    end;
  end
end;

procedure TFormMain.CheckAusteilen;
const cap : String = 'Austeilen';
var klasse : String;
begin
  if ListBox1.ItemIndex > -1 then begin
    klasse := ListBox1.Items[ ListBox1.ItemIndex ];
    if DirectoryExists( ESource.Text ) and (ListBox2.Count > 0) then begin
      BitBtn1.Caption := cap + '  (Verzeichnis)  --> ' + klasse;
      BitBtn1.Enabled := true;
    end else if FileExists( ESource.Text ) and (ListBox2.Count > 0) then begin
      BitBtn1.Caption := cap + '  (Datei)  --> ' + klasse;
      BitBtn1.Enabled := true;
    end else begin
      BitBtn1.Caption := cap;
      BitBtn1.Enabled := false;
    end;
  end else begin
    BitBtn1.Caption := cap;
    BitBtn1.Enabled := false;
  end;
end;

procedure TFormMain.ESourceChange(Sender: TObject);
begin
  CheckAusteilen;
end;

procedure TFormMain.BitBtn1Click(Sender: TObject);
begin
  Label2.Caption := '';
  if DirectoryExists( ESource.Text )
        then Austeilen
        else if FileExists( ESource.Text ) then Austeilen;
end;

function TFormMain.GetTeilnehmerFromSource( source:String ) : String;
var i:integer;
begin
  result := '';
  for i:=0 to FTeilnehmer.Count-1 do begin
    if ContainsText( source, FTeilnehmer.Strings[i] ) then begin
      result := FTeilnehmer.Strings[i];
      break;
    end;
  end;
end;

procedure TFormMain.BitBtn2Click(Sender: TObject);
var i,k:integer; folder, source, target, targetPrefix, targetPath:String;
    liste:TStringList;   b:boolean;
begin
  //- Einsammeln...
  { Über alle Teilnehmerverzeichnisse...
         Dateiliste erstellen
         Datei kopieren, dabei ggf. vorhandenen Zieldateien überschreiben und fehlende Ordner anlegen
  }
  liste := TStringList.Create;
  MemoEinsammeln.Clear;
  //targetprefix ist der Pfad, in dem die eingesammelten Files landen sollen
  targetPrefix := IncludeTrailingPathDelimiter( IncludeTrailingPathDelimiter( FConfig.ReadString( 'Settings', 'Einsammeln', '' ) ) + FTargetSubDir );
  try
    for i:=0 to FTargets.Count-1 do begin
      //Teilnehmerverzeichnis mit Name des Teilnehmers
      folder := IncludeTrailingPathDelimiter( IncludeTrailingPathDelimiter( FTargets.Strings[i] ) + FTargetSubDir ) ;

      //Alle Dateien in diesem Quellordner auflisten
      liste.Clear;
      FindAllFiles( liste, folder, '*.*', true );

      if liste.Count > 0 then begin
        for k:=0 to liste.Count-1 do begin
          //Quelldatei aus dem einzusammelnden Verzeichnis eines Teilnehmers
          source := liste.Strings[k];

          //user mit source und Liste FTeilnehmer ermitteln und dann den Teil folder in source
          //durch den Teil target ersetzen. So ergibt sich das Zielverzeichnis für die zu kopierende Datei
          target := IncludeTrailingPathDelimiter( targetPrefix + GetTeilnehmerFromSource( source ) );
          target := StringReplace( source, folder, target, [rfReplaceAll,rfIgnoreCase] );

          //Jetzt noch das ggf. fehlende Verzeichnis erzeugen
          targetpath := ExtractFilePath( target );
          if not DirectoryExists(targetpath) then ForceDirectories(targetpath);

          //Jetzt die Dateien kopieren
          b := CopyFile( source, target, [cffOverwriteFile], true );
          if b then MemoEinsammeln.Append( 'Ok: ' + target )
               else MemoEinsammeln.Append( 'Fehler: ' + target );
        end;
      end else begin
        //keine Files gefunden
        MemoEinsammeln.Append( 'Keine Dateien gefunden: ' + target )
      end;
    end;
    Label11.Caption := IntToStr( MemoEinsammeln.Lines.Count ) + ' Elemente' ;
  finally
    FreeAndNIL( liste )
  end;
end;

{ Bestimmt den letzten Teil des Pfadnamens
}
function TFormMain.ExtractLastDir( s:String ) : String;
var L:TStringList;
begin
  result := 'KA';  //für Klassenarbeit, damit es nicht leer ist
  if DirectoryExists( s ) then begin
     L:=TStringList.Create;
     try
       L.Delimiter:= DirectorySeparator;
       L.StrictDelimiter:=true;
       L.DelimitedText := ExtractFilePath( s );
       while (L.Count>0) and ( trim(L.Strings[ L.Count-1 ]) = '' )  //Leerzeilen am Ende entfernen
          do L.Delete( L.Count-1 );
       if L.Count > 0 then result := L.Strings[ L.Count-1 ];
     finally
       FreeandNIL( L );
     end;
  end;
end;
{

- alle auszuteilenden Files stehen in FSourceFiles : TStringList;   //Liste der auszuteilenden Quelldateien
- bei den Teilnehmern muss folgender Ordner erzeugt werden:  FTargetSubDir: String;        //bei den Teilnehmern anzulegender Ordner
- Für alle Schüler:  Dateien kopieren
   alle Einträge in ListBox2:
      erweitern um FTargetSubDir/
      als Ziel für die Kopieraktion wählen

}
procedure TFormMain.Austeilen;
var i,k, total,failed:integer; dateiListe:TStringList;  b:boolean;  target, targetpath, s,x,t, sourcePath, errMsg:String;
begin
  if ListBox1.ItemIndex > -1 then begin
    dateiListe := TStringList.Create;
    MemoAusteilen.Lines.Clear;
    total := 0;  failed := 0;
    try
    sourcepath := IncludeTrailingPathDelimiter( ExtractFilePath( ESource.Text ) );
      for i:=0 to ListBox2.Count-1 do begin   //alle Ziele
        for k:=0 to FSourceFiles.Count-1 do begin
          //Quelldatei inkl. evtl. Unterverzeichnisse
          s := FSourceFiles.Strings[k];          //quelldatei inkl. Pfad
          x := StringReplace( s, sourcepath, '', [rfReplaceAll,rfIgnoreCase] ); //Dateiname mit evtl. Verzeichnis
          t := ListBox2.Items.Strings[i];        //Zielverzeichnis des Teilnehmers noch ohne FTargetSubDir
          target := IncludeTrailingPathDelimiter( IncludeTrailingPathDelimiter( t ) + FTargetSubDir ) + x; //Zieldatei inkl. Zielordner

          targetpath := ExtractFilePath( target );
          errMsg := '';
          inc( total );
          try
            if not DirectoryExists(targetpath) then ForceDirectories(targetpath);
            b := CopyFile( s, target, [cffOverwriteFile], true );
          except
            on E:Exception do begin
               errMsg := E.Message;
               b := false;
               inc( failed );
            end;
          end;
          if b then MemoAusteilen.Append( 'Ok: ' + target )
               else MemoAusteilen.Append( 'Fehler: ' + target );
          if errMsg <> '' then MemoAusteilen.Append('  --> ' + errMsg );
        end;
      end;

      Label2.Caption := Format( ' ausgeteilte Elemente: %0:d   davon fehlgeschlagen: %1:d', [total, failed] );

    finally
      FreeAndNIL( dateiListe );
    end;
  end;
end;


function TFormMain.GetCfgString( Section:String; Ident:String; default:String ) : String;
begin
  result := default;
  if assigned( FConfig ) then begin
    if FConfig.ValueExists( Section, Ident) then result := FConfig.ReadString( Section, Ident, default );
  end;
end;

procedure TFormMain.SBSelectFileClick(Sender: TObject);
var x:String;    i:integer;
begin
  x := GetCfgString( 'Settings', 'LastUsedDir', '' );
  if x <> '' then OpenDialog.InitialDir := IncludeTrailingPathDelimiter( x );
  if OpenDialog.Execute then begin
    ESource.Text := OpenDialog.FileName;
    FConfig.WriteString(  'Settings', 'LastUsedDir', ExtractFilePath(OpenDialog.FileName) )
  end;
  FTargetSubDir :=  ExtractLastDir( ExtractFilePath( ESource.Text ) );
  Label4.Caption := FTargetSubDir;
  Label10.Caption:= FTargetSubDir;
  if not assigned( FSourceFiles ) then FSourceFiles := TStringList.Create;
  FSourceFiles.Clear;
  FSourceFiles.Add( ESource.Text );
  Label6.Caption:= IntToStr( FSourceFiles.Count );

  x:='';
  for i:=0 to FSourceFiles.Count-1 do
      x := x + FSourceFiles.Strings[i] + #13 + #10;

  x := 'Ausgeteilt werden:' + #13 + #10 + x;
  ShowMessage( x );

end;

procedure TFormMain.SBSelectFolderClick(Sender: TObject);
var x:String;    i:integer;
begin
  x := GetCfgString( 'Settings', 'LastUsedDir', '' );
  if x <> '' then OpenDialog.InitialDir := IncludeTrailingPathDelimiter( x );
  if SelectDirectoryDialog.Execute then begin
    ESource.Text := IncludeTrailingPathDelimiter( SelectDirectoryDialog.FileName );
    FConfig.WriteString(  'Settings', 'LastUsedDir', ESource.Text );
  end;
  FTargetSubDir :=  ExtractLastDir( IncludeTrailingPathDelimiter( ESource.Text ) );
  Label4.Caption := FTargetSubDir;
  Label10.Caption := FTargetSubDir;
  if assigned( FSourceFiles ) then FreeAndNIL( FSourceFiles );
  FSourceFiles := FindAllFiles( IncludeTrailingPathDelimiter( ESource.Text ), '*.*' );
  Label6.Caption:= IntToStr( FSourceFiles.Count );

  x:='';
  for i:=0 to FSourceFiles.Count-1 do
      x := x + FSourceFiles.Strings[i] + #13 + #10;
  ShowMessage( x );
end;

function TFormMain.isFile( Ident:String ) : boolean;
var F:LongInt;
begin
  F:=FileGetAttr(Ident);
  result := (F and faDirectory) = 0;
end;

function TFormMain.isDirectory( Ident:String ) : boolean;
var F:LongInt;
begin
  F:=FileGetAttr(Ident);
  result := (F and faDirectory) <> 0;
end;

procedure TFormMain.ReadClassList;
var drive : String;    liste:TStringList;   i:integer;
begin
  drive := ExtractFileDrive( FConfig.ReadString( 'Settings', 'AllClasses', 'I:\' ) );
  drive := IncludeTrailingPathDelimiter( drive );
  liste := TStringList.Create;
  try
    FindAllDirectories( liste, drive, false );
    for i:=0 to liste.Count-1 do begin
      ListBox1.AddItem( Copy( liste.Strings[i], length(drive)+1, length(liste.Strings[i])), nil );
    end;
  finally
    FreeAndNIL( liste );
  end;
end;


function TFormMain.GetShortcutTarget(const ShortcutFilename: string): string;
var
  Psl: IShellLink;
  Ppf: IPersistFile;
  WideName: array[0..MAX_PATH] of WideChar;
  pResult: array[0..MAX_PATH-1] of ansiChar;
  Data: TWin32FindData;
const
  IID_IPersistFile: TGUID = (
    D1:$0000010B; D2:$0000; D3:$0000; D4:($C0,$00,$00,$00,$00,$00,$00,$46));
begin
  CoCreateInstance(CLSID_ShellLink, nil, CLSCTX_INPROC_SERVER, IID_IShellLinkA, psl);
  psl.QueryInterface(IID_IPersistFile, ppf);
  MultiByteToWideChar(CP_ACP, 0, pAnsiChar(ShortcutFilename), -1, WideName, Max_Path);
  ppf.Load(WideName, STGM_READ);
  psl.Resolve(0, SLR_ANY_MATCH);
  psl.GetPath(@pResult, MAX_PATH, Data, SLGP_UNCPRIORITY);
  Result := StrPas(pResult);
end;






//
//Procedure TFormMain.FindFiles (aPath, aFindMask: String; aWithSub: Boolean; Attr : Longint; aResult: tStrings);
//Var
//  FindRec: tSearchRec;
//  CFE:string;
//Begin
//  // Wenn die Stringliste nil ist oder aPath oder aFind nicht angegeben ist
//  // dann raus
//  If (aPath = '') or (aFindMask = '') or Not Assigned (aResult) Then
//    Exit;
//  // Wenn am Ende der Pfadangabe noch kein \ steht, dieses hinzufügen
//  If aPath[Length (aPath)] <> '\' Then
//    aPath := aPath + '\';
//  // Im aktuellen Verzeichnis nach der Datei suchen
//  If FindFirst (aPath + aFindMask, faAnyFile, FindRec) = 0 Then
//    Repeat
//      If (FindRec.Name <> '.') and (FindRec.Name <> '..') Then // ...Ergebnis in die Stringlist einfügen
//        Begin
//        if ((FindRec.Attr and Attr) > 0) then begin
//          CFE:=ChangeFileExt(FindRec.Name, '');
//          aResult.Add ({aPath +}CFE); //Pfad ausschließen...
//        end;
//        end;
//    Until FindNext (FindRec) <> 0;
//  FindClose (FindRec);
//End;
//
//



end.

