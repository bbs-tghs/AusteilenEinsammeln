unit uKlasse;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, Contnrs;

type TKlasse = class(TObject)
  private
    FName : String;
  protected
  public
    property Name : String read FName write FName;
end;


type TKlassen = class(TObject)
  private
    FList : TObjectList;
  protected
    procedure  SetItems(i: integer; const AValue : TKlasse);
    function  GetItems(i: integer): TKlasse;

  public
    Constructor Create;
    Destructor  Destroy; override;
    property    Items[Index:integer] : TKlasse read GetItems write SetItems;
    function    Add( Item : TKlasse ) : integer;
    function    Count : integer;
end;





implementation




Constructor TKlassen.Create;
begin
  inherited Create;
  FList := TObjectList.Create( true );
end;

Destructor  TKlassen.Destroy;
begin
  FList.Clear;
  FreeAndNIL( FList );
  inherited Destroy;
end;

procedure TKlassen.SetItems(i: integer; const AValue : TKlasse);
begin
  FList.Items[i] := AValue;
end;

function TKlassen.GetItems(i: integer): TKlasse;
begin
  result := FList.Items[i] as TKlasse;
end;

function TKlassen.Add( Item : TKlasse ) : integer;
begin
  result := FList.Add( Item );
end;

function TKlassen.Count : integer;
begin
  result := FList.Count;
end;

end.

