{
  Object Relational Mapping unit built on top of Greyhound project

  The idea is to automate saving and loading of published properties
  Note that the API is not yet stable, it might change in the future
  without notice
}
unit ghORM;

{$mode objfpc}{$H+}
{$assertions on}
{$M+}

interface

uses
  gh_DB;

type

  { TghModel }

  TghModel = class
  protected
    FID: Integer;
    class function NewID: Integer;
    function GetTable: TghDBTable;
  public
    constructor Create; virtual;
    constructor Create(const AID: Integer);
    procedure Save; virtual;
    procedure Load; virtual;
  published
    property ID: Integer read FID;
  end;

  TghModelClass = class of TghModel;

procedure RegisterClass(AClass: TghModelClass);
procedure RegisterClass(AClass: TghModelClass; const AName: String);

procedure SetConnection(const ABroker: TghDBConnectorBrokerClass; const ADBName: String);
function GetConnection: TghDBConnector; inline;

implementation

uses
  SysUtils,TypInfo,gmap;

type

  { TghModelClassLess }

  TghModelClassLess = class
    class function c(a,b:TghModelClass):boolean;inline;
  end;

  TClassMap = specialize TMap<TghModelClass,String,TghModelClassLess>;

var
  Connection: TghDBConnector;
  ClassMap: TClassMap;

procedure RegisterClass(AClass: TghModelClass);
var
  ClassName: String;
begin
  ClassName := AClass.ClassName;
  Delete(ClassName,1,1);
  RegisterClass(AClass,ClassName);
end;

procedure RegisterClass(AClass: TghModelClass; const AName: String);
begin
  ClassMap[AClass] := AName;
end;

procedure SetConnection(const ABroker: TghDBConnectorBrokerClass; const ADBName: String);
begin
  if Assigned(Connection) then Connection.Free;
  Connection := TghDBConnector.Create;
  with Connection do begin
    SetBrokerClass(ABroker);
    Database := ADBName;
    Connect;
  end;
end;

function GetConnection: TghDBConnector; inline;
begin
  Result := Connection;
  Assert(Assigned(Result));
end;

{ TghModelClassLess }

class function TghModelClassLess.c(a,b: TghModelClass): boolean;
begin
  Result := PtrUInt(a) < PtrUInt(b);
end;

{ TghModel }

class function TghModel.NewID: Integer;
var
  ClsType: TClass;
begin
  ClsType := ClassType;
  Result := Connection.Tables[ClassMap[TghModelClass(ClsType)]].Select('Count(*) + 1 AS c').Open.Columns['c'].AsInteger;
end;

function TghModel.GetTable: TghDBTable;
var
  ClsType: TClass;
begin
  ClsType := ClassType;
  Result := GetConnection.Tables[ClassMap[TghModelClass(ClsType)]].Where('id = ' + IntToStr(FID)).Open;
end;

constructor TghModel.Create;
begin
  FID := NewID;
end;

constructor TghModel.Create(const AID: Integer);
begin
  FID := AID;
  if not GetTable.EOF then
    Load
  else
    raise EghDBError.CreateFmt(
      'No row in table %s having ID = %d',
      [ClassMap[TghModelClass(ClassType)],AID]
    );
end;

procedure TghModel.Save;
var
  t: TghDBTable;
  PropCount,i: Integer;
  Props: PPropList;
  Prop: PPropInfo;
begin
  t := GetTable;
  PropCount := GetPropList(Self,Props);
  try
    if t.EOF then t.Insert else t.Edit;
    for i := 0 to PropCount - 1 do begin
      Prop := Props^[i];
      case Prop^.PropType^.Kind of
        tkInteger, tkChar, tkWChar, tkBool:
          t.Columns[Prop^.Name].AsInteger := GetOrdProp(Self,Prop);
        tkFloat:
          t.Columns[Prop^.Name].AsFloat := GetFloatProp(Self,Prop);
        tkString, tkAString, tkLString:
          t.Columns[Prop^.Name].AsString := GetStrProp(Self,Prop);
        tkWString:
          t.Columns[Prop^.Name].AsWideString := GetWideStrProp(Self,Prop);
        tkInt64, tkQWord:
          t.Columns[Prop^.Name].AsLargeInt := GetInt64Prop(Self,Prop);
      end;
    end;
    t.Post;
    t.Commit;
  finally
    FreeMem(Props);
  end;
end;

procedure TghModel.Load;
var
  t: TghDBTable;
  PropCount,i: Integer;
  Props: PPropList;
  Prop: PPropInfo;
begin
  PropCount := GetPropList(Self,Props);
  try
    t := GetTable;
    for i := 0 to PropCount - 1 do begin
      Prop := Props^[i];
      case Prop^.PropType^.Kind of
        tkInteger, tkChar, tkWChar, tkBool:
          SetOrdProp(Self,Prop,t.Columns[Prop^.Name].AsInteger);
        tkFloat:
          SetFloatProp(Self,Prop,t.Columns[Prop^.Name].AsFloat);
        tkString, tkAString, tkLString:
          SetStrProp(Self,Prop,t.Columns[Prop^.Name].AsString);
        tkWString:
          SetWideStrProp(Self,Prop,t.Columns[Prop^.Name].AsWideString);
        tkInt64, tkQWord:
          SetInt64Prop(Self,Prop,t.Columns[Prop^.Name].AsLargeInt);
      end;
    end;
  finally
    FreeMem(Props);
  end;
end;

initialization
  Connection := nil;
  ClassMap := TClassMap.Create;

finalization
  if Assigned(Connection) then Connection.Free;
  ClassMap.Free;

end.
