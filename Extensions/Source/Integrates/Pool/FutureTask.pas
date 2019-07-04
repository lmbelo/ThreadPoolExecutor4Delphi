{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit FutureTask;

interface

uses
  RunnableFuture, Callable, Classes, ThreadPoolExecutor, SysUtils, Future, 
  ExecutorService, Exceptions, Runnable;

type
  TWaitNode = class sealed
  strict private
    FThreadId: cardinal;
    FNext: TWaitNode;
  public
    constructor Create();

    property ThreadId: cardinal read FThreadId write FThreadId;
    property Next: TWaitNode read FNext write FNext;
  end;

  TFutureTask = class(TInterfacedObject, ITaskFuture, IRunnable, IFuture)
  private
    const NEW: byte          = 0;
    const COMPLETING: byte   = 1;
    const NORMAL: byte       = 2;
    const EXCEPTIONAL: byte  = 3;
    const CANCELLED: byte    = 4;
    const INTERRUPTING: byte = 5;
    const INTERRUPTED: byte  = 6;
  private
    FState: integer;
    FCallable: ICallable;
    FOutCome: pointer;
    FRunner: TThread;
    FWaiters: TWaitNode;
  private
    procedure Report(const AState: byte; out AResult: pointer);
    procedure HandlePossibleCancellationInterrupt(const AState: byte);
    procedure FinishCompletition();
    function AwaitDone(const ATimed: boolean; const ATimeOut: Int64): integer;
    procedure RemoveWaiter(const ANode: TWaitNode);
  protected
    procedure Done(); virtual;
    procedure SetResult(var AResult: pointer);
    procedure SetException(const E: Exception);
    function RunAndReset(): boolean;
  public
    constructor Create(const ACallable: ICallable); overload;
    constructor Create(const ATask: IRunnable; var AResult: pointer); overload;
    destructor Destroy(); override;

    //IFuture implementation
    function Cancel(const AInterruptIfRunning: boolean): boolean;
    function IsCancelled(): boolean;
    function IsDone(): boolean;
    procedure GetResult(out AResult: pointer); overload;
    procedure GetResult(const ATimeOut: Int64; out AResult: pointer); overload;

    //ITaskFuture implementation
    procedure Run();
  end;

implementation

uses
  Threading, Executors, DateUtils, Windows, Contnrs, SyncObjs;

type
  TInterlocked = class sealed
  public
    class function CompareExchange(var ADestination: integer; const AExchange: integer; const AComparand: integer): boolean; static;
    class function CompareExchangePointer(var ADestination: pointer; const AExchange: pointer; const AComparand: pointer): boolean; static;
    class procedure Exchange(var ATarget: integer; const AValue: integer); static;
    class procedure ExchangePointer(var ATarget: pointer; const AValue: pointer); static;
  end;

  TLockSuport = class sealed
  private type
    TParkedList = class(TStringList)
    private
      class var FInstance: TParkedList;
    private
      FCriticalSection: TCriticalSection;
    public
      constructor Create();
      destructor Destroy(); override;
      procedure Park(const AThreadId: integer);
      function IsParked(const AThreadId: integer): boolean;
      procedure UnPark(const AThreadId: integer);
      class procedure Initialize;
      class procedure Finalize;
      class function GetInstance: TParkedList;
    end;
  public
    class procedure ParkMilli(const ATimeOut: Int64); static;
    class procedure Park(); static;
    class procedure UnPark(const AThreadId: integer); static;
  end;

{ TFutureTask }

constructor TFutureTask.Create(const ATask: IRunnable; var AResult: pointer);
begin
  FCallable := TExecutors.Callable(ATask, AResult);
  FState := NEW;  
end;

constructor TFutureTask.Create(const ACallable: ICallable);
begin
  if not Assigned(ACallable) then raise ENullPointer.Create();
  FCallable := ACallable;
  FState := NEW;
end;

function TFutureTask.AwaitDone(const ATimed: boolean; const ATimeOut: Int64): integer;
var
  LDeadLine: TDateTime;
  LQ: TWaitNode;
  LQueued: boolean;
  LCurThread: TCustomThread;
  LState: byte;
  LNow: TDateTime;
begin                   
  LDeadLine := MinDateTime;
  if ATimed then begin
    LDeadLine := Now();
    LDeadLine := IncMilliSecond(LDeadLine, ATimeOut);
  end;
  LQ := nil;
  LQueued := false;
  while true do begin
    LCurThread := TCustomThread.GetCurrentThread() as TCustomThread;
    if Assigned(LCurThread) and LCurThread.Interrupted then begin
      try
        RemoveWaiter(LQ);
      finally
        FreeAndNil(LQ);
      end;
      raise EInterrupted.Create();
    end;

    LState := FState;
    if (LState > COMPLETING) then begin
      if Assigned(LQ) then begin
        LQ.ThreadId := 0;
        FreeAndNil(LQ);
      end;
      Result := LState;
      Exit;
    end else if (LState = COMPLETING) then begin
      TCustomThread.Yield();
    end else if not Assigned(LQ) then begin
      LQ := TWaitNode.Create();
    end else if not LQueued then begin
      LQ.Next := FWaiters;
      LQueued := (TInterlocked.CompareExchangePointer(
                   pointer(FWaiters),
                   pointer(LQ),
                   pointer(LQ.Next)));
    end else if ATimed then begin
      LNow := Now();
      if (MilliSecondsBetween(LNow, LDeadLine) <= 0 ) then begin
        try
          RemoveWaiter(LQ);
        finally
          FreeAndNil(LQ);
        end;
        Result := LState;
        Exit;
      end;
      TLockSuport.ParkMilli(ATimeOut);
    end else begin
      TLockSuport.Park();
    end;
  end;
end;

function TFutureTask.Cancel(const AInterruptIfRunning: boolean): boolean;
var
  LRunner: TThread;
begin
  if (FState <> NEW) then begin
    Result := false;
    Exit;             
  end else if AInterruptIfRunning then begin
    if not TInterlocked.CompareExchange(FState, INTERRUPTING, NEW) then begin
      Result := false;
      Exit;
    end;

    LRunner := FRunner;
    if Assigned(LRunner) then TCustomThread(LRunner).Interrupt();

    TInterlocked.Exchange(FState, INTERRUPTED);
  end else if (not TInterlocked.CompareExchange(FState, CANCELLED, NEW)) then begin
    Result := false;
    Exit;
  end;
  FinishCompletition();
  Result := true;
end;

destructor TFutureTask.Destroy;
begin
  inherited;
end;

procedure TFutureTask.Done;
begin
  //
end;

procedure TFutureTask.Run;
var
  LState: Integer;
  LCallable: ICallable;
  LResult: Pointer;
  LRan: Boolean;
begin
  if (FState <> NEW) or (not TInterlocked.CompareExchangePointer(
                               pointer(FRunner),
                               pointer(TCustomThread.GetCurrentThread()),
                               nil)) then begin
    Exit;
  end;
  try
    LCallable := FCallable;
    LResult := nil;
    try
      LCallable.Call(LResult);
      LRan := true;
    except
      on E: Exception do begin
        LResult := nil;
        LRan := false;
        SetException(Exception(AcquireExceptionObject()));
      end;
    end;
    if LRan then SetResult(LResult);
  finally
    FRunner := nil;
    LState := FState;
    if (LState <> INTERRUPTING) then HandlePossibleCancellationInterrupt(LState);
  end;
end;

procedure TFutureTask.FinishCompletition;
var
  LQ: TWaitNode;
  LThreadId: cardinal;
  LNext: TWaitNode;
begin
  LQ := FWaiters;
  while Assigned(LQ) do begin
    if (TInterlocked.CompareExchangePointer(pointer(FWaiters),
                                            nil,
                                            pointer(LQ))) then begin 
      while true do begin
        LThreadId := LQ.ThreadId;
        if (LThreadId > 0) then begin
          LQ.ThreadId := 0;
          TLockSuport.UnPark(LThreadId);
        end;
        LNext := LQ.Next;
        if not Assigned(LNext) then begin
          Break;
        end;
        LQ.Next := nil;
        LQ := LNext;
      end;
      Break;
    end;
  end;
  done();
  FCallable := nil;
end;

procedure TFutureTask.GetResult(out AResult: pointer);
var
  LState: Integer;
begin
  LState := FState;
  if (LState <= COMPLETING) then begin
    LState := AwaitDone(false, 0);
  end;
  Report(LState, AResult);
end;

procedure TFutureTask.GetResult(const ATimeOut: Int64; out AResult: pointer);
var
  LState: Integer;
begin
  LState := FState;
  if (LState <= COMPLETING) then begin
    LState := AwaitDone(true, ATimeOut);
    if (LState <= COMPLETING) then raise ETimeOut.Create();
  end;
  Report(LState, AResult);
end;

procedure TFutureTask.HandlePossibleCancellationInterrupt(const AState: byte);
begin
  if (AState = INTERRUPTING) then begin
    while (FState = INTERRUPTING) do begin
      TCustomThread.Yield;
    end;
  end;
end;

function TFutureTask.IsCancelled: boolean;
begin
  Result := FState >= CANCELLED;
end;

function TFutureTask.IsDone: boolean;
begin
  Result := FState <> NEW;
end;

procedure TFutureTask.RemoveWaiter(const ANode: TWaitNode);
label
  LRetry;
var
  LPred: TWaitNode;
  LQ: TWaitNode;
  LS: TWaitNode;
begin
  if Assigned(ANode) then begin
    ANode.ThreadId := 0;

    LRetry:
      while true do begin
        LPred := nil;
        LQ := FWaiters;
        while Assigned(LQ) do begin
          LS := LQ.Next;
          if (LQ.ThreadId > 0) then begin
            LPred := LQ;
          end else if Assigned(LPred) then begin
            LPred.Next := LS;
            if not (LPred.ThreadId > 0) then begin
              goto LRetry;
            end;
          end else if (not TInterlocked.CompareExchangePointer(
                             pointer(FWaiters),
                             LS,
                             LQ)) then begin
            goto LRetry;
          end;
          LQ := LS;
        end;
        Break;
      end;
  end;
end;

procedure TFutureTask.Report(const AState: byte; out AResult: pointer);
begin
  if (AState = NORMAL) then begin
    AResult := FOutCome;
  end else if (AState = CANCELLED) then begin
    raise ECancellation.Create('Task cancelled.');
  end else begin
    raise Exception(FOutCome);
  end;
end;

function TFutureTask.RunAndReset: boolean;
var
  LRan: boolean;
  LState: byte;
  LCallable: ICallable;
  LNil: pointer;
begin
  if (FState <> NEW) or (not TInterlocked.CompareExchangePointer(
                               pointer(FRunner),
                               pointer(TCustomThread.GetCurrentThread()),
                               nil)) then begin
    Result := false;
    Exit;
  end;
  LRan := false;
  LState := FState;
  try
    LCallable := FCallable;
    if Assigned(FCallable) and (LState = NEW) then begin
      try
        LNil := nil;
        LCallable.Call(LNil);
        LRan := true;
      except
        on E: Exception do begin
          SetException(Exception(AcquireExceptionObject()));
        end;
      end;
    end;
  finally
    LState := FState;
    if (LState >= INTERRUPTING) then begin
      HandlePossibleCancellationInterrupt(LState);
    end;
  end;
  Result := LRan and (LState = NEW);
end;

procedure TFutureTask.SetException(const E: Exception);
begin
  if (TInterlocked.CompareExchange(FState, COMPLETING, NEW)) then begin
    FOutCome := pointer(E);
    TInterlocked.Exchange(FState, EXCEPTIONAL);
    FinishCompletition();
  end;
end;

procedure TFutureTask.SetResult(var AResult: pointer);
begin
  if (TInterlocked.CompareExchange(FState, COMPLETING, NEW)) then begin
    FOutCome := AResult;
    TInterlocked.Exchange(FState, NORMAL);
    FinishCompletition();
  end;
end;

{ TWaitNode }

constructor TWaitNode.Create;
begin
  FThreadId := GetCurrentThreadId();  
end;

{ TInterlocked }

class function TInterlocked.CompareExchange(var ADestination: integer;
  const AExchange, AComparand: integer): boolean;
begin
  Result := Windows.InterlockedCompareExchange(ADestination,
                                               AExchange,
                                               AComparand) = AComparand;
end;

class function TInterlocked.CompareExchangePointer(var ADestination: pointer;
  const AExchange, AComparand: pointer): boolean;
begin
  Result := Windows.InterlockedCompareExchange(integer(ADestination),
                                               integer(AExchange),
                                               integer(AComparand))
            = integer(AComparand);
end;

class procedure TInterlocked.Exchange(var ATarget: integer;
  const AValue: integer); 
begin
  Windows.InterlockedExchange(ATarget, AValue);
end;

class procedure TInterlocked.ExchangePointer(var ATarget: pointer;
  const AValue: pointer);
begin
  Windows.InterlockedExchange(integer(ATarget), integer(AValue));
end;

{ TLockSuport }

class procedure TLockSuport.Park();
var
  LThreadId: Cardinal;
begin
  LThreadId := GetCurrentThreadId();
  TParkedList.GetInstance().Park(LThreadId);
  try
    while TParkedList.GetInstance().IsParked(LThreadId) do begin
      SleepEx(100, true);
    end;
  except
    on E: Exception do begin
      TParkedList.GetInstance().UnPark(LThreadId);
      raise;
    end;
  end;
end;

class procedure TLockSuport.ParkMilli(const ATimeOut: Int64);
var
  LThreadId: cardinal;
  LDeadLine: TDateTime;
  LNow: TDateTime;
begin
  LThreadId := GetCurrentThreadId();
  TParkedList.GetInstance().Park(LThreadId);
  try
    LNow := Now();
    LDeadLine := IncMilliSecond(LNow, ATimeOut);
    try
      while (MilliSecondsBetween(LNow, LDeadLine) > 0)
        and TParkedList.GetInstance().IsParked(LThreadId) do begin
          SleepEx(100, true);
          LNow := Now();
      end;
    finally
      TParkedList.GetInstance().UnPark(LThreadId);
    end;
  except
    on E: Exception do begin
      TParkedList.GetInstance().UnPark(LThreadId);
      raise;
    end;
  end;
end;

class procedure TLockSuport.UnPark(const AThreadId: integer);
begin
  TParkedList.GetInstance().UnPark(AThreadId);
end;

{ TLockSuport.TParkedList }

constructor TLockSuport.TParkedList.Create;
begin
  inherited Create();
  FCriticalSection := TCriticalSection.Create();
  Self.Duplicates := dupError;
  Self.Sorted := true;
end;

destructor TLockSuport.TParkedList.Destroy;
begin
  FCriticalSection.Free();
  inherited;
end;

class procedure TLockSuport.TParkedList.Finalize;
begin
  FreeAndNil(FInstance);
end;

class function TLockSuport.TParkedList.GetInstance: TParkedList;
begin
  Result := FInstance;
end;

class procedure TLockSuport.TParkedList.Initialize;
begin
  if not Assigned(FInstance) then
    FInstance := TParkedList.Create();
end;

function TLockSuport.TParkedList.IsParked(const AThreadId: integer): boolean;
begin
  FCriticalSection.Acquire;
  try
    Result := Self.IndexOf(IntToStr(AThreadId)) > -1;
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TLockSuport.TParkedList.Park(const AThreadId: integer);
begin
  FCriticalSection.Acquire;
  try
    Self.Add(IntToStr(AThreadId));
  finally
    FCriticalSection.Leave;
  end;
end;

procedure TLockSuport.TParkedList.UnPark(const AThreadId: integer);
begin
  FCriticalSection.Acquire;
  try
  if Self.IndexOf(IntToStr(AThreadId)) > -1 then
    Self.Delete(Self.IndexOf(IntToStr(AThreadId)));
  finally
    FCriticalSection.Leave;
  end;
end;

initialization
  TLockSuport.TParkedList.Initialize;

finalization
  TLockSuport.TParkedList.Finalize;

end.
