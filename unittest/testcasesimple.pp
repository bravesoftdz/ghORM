unit testcasesimple;

{$mode objfpc}{$H+}

interface

uses
  Classes, SysUtils, fpcunit, testutils, testregistry;

type

  { TSimpleTestCase }

  TSimpleTestCase = class(TTestCase)
  protected
    procedure SetUp; override;
    procedure TearDown; override;
  published
    procedure InsertNewLoadExisting;
    procedure LoadNotExisting;
    procedure Reset;
  end;

implementation

uses
  gh_DB, gh_DBSQLdb, ghorm, models;

var
  gid: Integer;

procedure TSimpleTestCase.InsertNewLoadExisting;
var
  u: TUsers;
  id: Integer;
begin
  u := TUsers.Create;
  u.Name := 'Mario';
  u.Age := 24;
  u.Birthdate := '25-03-88';
  u.Save;

  id := u.ID;

  u.Free;

  u := TUsers.Create(id);

  AssertEquals(u.Name,'Mario');
  AssertEquals(u.Age,24);
  AssertEquals(u.Birthdate,'25-3-88');

  u.Free;

  gid := id;
end;

procedure TSimpleTestCase.LoadNotExisting;
var
  u: TUsers;
begin
  try
    u := TUsers.Create(255);
  except
    on e: EghDBError do
      Exit;
    on e: Exception do
      Fail('Unexpected ' + e.ClassName + ': ' + e.Message);
  end;
  Fail('Exception expected');
end;

procedure TSimpleTestCase.Reset;
var
  u: TUsers;
begin
  u := TUsers.Create(gid);

  u.Name := 'Marijan';
  u.Age := 72;
  u.Birthdate := '1-1-99';

  u.Load;

  AssertEquals(u.Name,'Mario');
  AssertEquals(u.Age,24);
  AssertEquals(u.Birthdate,'25-3-88');

  u.Free;
end;

procedure TSimpleTestCase.SetUp;
begin
  SetConnection(TghDBSQLite3Broker,'test.db');
end;

procedure TSimpleTestCase.TearDown;
begin
  GetConnection.Tables['users'].Open.Delete;
end;

initialization
  RegisterTest(TSimpleTestCase);

end.
