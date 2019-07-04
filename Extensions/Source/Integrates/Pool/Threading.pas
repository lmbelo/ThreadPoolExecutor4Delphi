{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit Threading;

interface

uses
  Classes, Contnrs, SyncObjs;

type
  TThreadManager = class
  strict private
    class function GetInstance: TThreadManager; static;
  private
    class var FInstance: TThreadManager;
  private
    class procedure Initialize;
    class procedure Finalize;
  private
    FThreads: TStrings;
    FLock: TCriticalSection;
  public
    constructor Create;
    destructor Destroy; override;

    procedure AddThread(const AThread: TThread);
    procedure RemoveThread(const AThread: TThread);
    function GetThreadById(const AThreadId: cardinal): TThread;

    class function GetCurrentThread(): TThread;

    class property Instance: TThreadManager read GetInstance;
  end;

  TCustomThread = class(TThread)
  private
    FInterrupted: boolean;
  protected
    procedure HandleInterruption;
  public
    procedure AfterConstruction; override;
    procedure BeforeDestruction; override;

    procedure Interrupt;
    procedure Sleep(const AMilliseconds: cardinal);

    class procedure Yield;
    class function GetCurrentThread: TThread;
    class function GetCurrentThreadId: cardinal;

    property Interrupted: boolean read FInterrupted;
  end;

implementation

uses
  SysUtils, Windows, Exceptions;

{ TCustomThread }

procedure TCustomThread.AfterConstruction;
begin
  FInterrupted := false;
  TThreadManager.Instance.AddThread(Self);
  inherited;
end;

procedure TCustomThread.BeforeDestruction;
begin
  TThreadManager.Instance.RemoveThread(Self);
  inherited;
end;

class function TCustomThread.GetCurrentThread: TThread;
begin
  Result := TThreadManager.Instance.GetThreadById(GetCurrentThreadId);
end;

class function TCustomThread.GetCurrentThreadId: cardinal;
begin
  Result := Windows.GetCurrentThreadId();
end;

procedure TCustomThread.HandleInterruption;
  procedure DoInterrupt();
  begin
    raise EInterrupted.Create();
  end;
begin
  if FInterrupted then Exit;
  QueueUserAPC(Addr(DoInterrupt), Self.Handle, Cardinal(Self));
  FInterrupted := true;
end;

procedure TCustomThread.Interrupt;
begin
  HandleInterruption;
end;

procedure TCustomThread.Sleep(const AMilliseconds: cardinal);
begin
  FInterrupted := false;
  SleepEx(AMilliseconds, true);
end;

class procedure TCustomThread.Yield;
begin
  Windows.Sleep(0);
end;

{ TThreadManager }

constructor TThreadManager.Create;
begin
  FLock := TCriticalSection.Create;
  FThreads := TStringList.Create;
end;

destructor TThreadManager.Destroy;
begin
  FThreads.Free;
  FLock.Free;
  inherited;
end;

class procedure TThreadManager.Finalize;
begin
  FInstance.Free;
end;

class function TThreadManager.GetCurrentThread: TThread;
begin
  Result := TThreadManager.Instance.GetThreadById(GetCurrentThreadId()); 
end;

class function TThreadManager.GetInstance: TThreadManager;
begin
  if not Assigned(FInstance) then FInstance := TThreadManager.Create;
  Result := FInstance;
end;

procedure TThreadManager.AddThread(const AThread: TThread);
begin
  FLock.Acquire;
  try
    FThreads.AddObject(IntToStr(AThread.ThreadID), AThread);
  finally
    FLock.Release;
  end;
end;

procedure TThreadManager.RemoveThread(const AThread: TThread);
var
  LIx: Integer;
begin
  FLock.Acquire;
  try
    LIx := FThreads.IndexOf(IntToStr(AThread.ThreadID));
    if LIx >= 0 then FThreads.Delete(LIx);
  finally
    FLock.Release;
  end;
end;

function TThreadManager.GetThreadById(const AThreadId: cardinal): TThread;
var
  LCurThreadId: Cardinal;
  LIx: Integer;
begin    
  FLock.Acquire;
  try
    LCurThreadId := GetCurrentThreadId;
    LIx := FThreads.IndexOf(IntToStr(LCurThreadId));
    if LIx >= 0 then begin
      Result := FThreads.Objects[LIx] as TThread;
    end else begin
      Result := nil;
    end;
  finally
    FLock.Release;
  end;
end;

class procedure TThreadManager.Initialize;
begin
  FInstance := nil;
end;

initialization
  TThreadManager.Initialize();

finalization
  TThreadManager.Finalize();

end.
