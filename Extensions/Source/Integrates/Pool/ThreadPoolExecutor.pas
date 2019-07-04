{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit ThreadPoolExecutor;

interface

uses
  Classes,
  SysUtils,
  Contnrs,
  SyncObjs, BlockingQueue, Threading, ExecutorService, AbstractExecutorService, 
  Runnable;

type
  TWorker = class;

  TThreadPooled = class;

  IThreadPooledFactory = interface
    ['{8CAC8A6A-34E7-40D6-9CE6-6A45C78D2BCD}']
    function CreateThread(const AWorker: TWorker): TThreadPooled;
  end;

  IRejectedExecutionHandler = interface;

  TThreadPoolExecutor = class(TAbstractExecutorService)
  private  
    FWorkers: TObjectList;
    FWorkQueue: TInterfaceBlockingQueue;
    FLock:TCriticalSection;
    FLargestPoolSize: integer;
    FCompletedTaskCount: integer;
    FPoolSize:integer;
    FKeepAliveTime: integer;
    FAllowCoreThreadTimeOut: boolean;
    FCorePoolSize: integer;
    FMaximumPoolSize: integer;
    FRunState: byte;
    FThreadPooledFactory: IThreadPooledFactory;
    FRejectedExecutionHandler: IRejectedExecutionHandler;
    FOwnedQueue: boolean;
  private
    const STATE_RUNNING = 0;
    const STATE_SHUTDOWN = 1;
    const STATE_STOP = 2;
    const STATE_TERMINATED = 3;
  strict private
    procedure SetMaximumPoolSize(val : Integer);
    procedure SetCorePoolSize(val : Integer);
    procedure SetKeepAliveTime(val : Integer);
    procedure SetRejectedExecutionHandler(const Value: IRejectedExecutionHandler);
    procedure SetAllowCoreThreadTimeOut(const Value: boolean);
    procedure SetThreadPooledFactory(const Value: IThreadPooledFactory);
    function GetLargestPoolSize: integer;
  private
    function AddThread(const AFirstTask: IRunnable): TThread;
    function AddIfUnderCorePoolSize(const AFirstTask: IRunnable): boolean;
    function AddIfUnderMaximumPoolSize(const AFirstTask: IRunnable): integer;
    procedure InterruptIdleWorkers;
    procedure WorkerDone(const AWorker: TWorker);
    procedure Reject(const ATask: IRunnable);
  protected
    function GetTask: IRunnable;
    procedure BeforeExecute(const AThread: TThread; const ATask: IRunnable); virtual;
    procedure AfterExecute(const ATask: IRunnable; const AException: Exception); virtual;
    procedure Terminated; virtual;
  public
    constructor Create(const ACorePoolSize, AMaximumPoolSize, AKeepAliveTime: integer; const AWorkQueue: TInterfaceBlockingQueue);overload;
    constructor Create(const ACorePoolSize, AMaximumPoolSize, AKeepAliveTime: integer; const AWorkQueue: TInterfaceBlockingQueue; const AThreadFactory: IThreadPooledFactory);overload;
    constructor Create(const ACorePoolSize, AMaximumPoolSize, AKeepAliveTime: integer; const AWorkQueue: TInterfaceBlockingQueue; const AThreadFactory: IThreadPooledFactory; const ARejectedExecutionHandler: IRejectedExecutionHandler);overload;
    destructor Destroy(); override;

    procedure Execute(const ATask: IRunnable); override;
    function Remove(const ATask: IRunnable): boolean;

    procedure Shutdown; override;
    function ShutdownNow: TRunnableArray; override;
    function IsShutdown: boolean; override;
    function IsTerminated: boolean; override;
    function AwaitTermination(const ATimeout: int64): boolean; override;
    function IsTerminating: boolean;
    function PrestartCoreThread: boolean;
    function PrestartAllCoreThreads: integer;
    function GetActiveCount: integer;
    function GetTaskCount: integer;
    function GetCompletedTaskCount: integer;

    property ThreadFactory: IThreadPooledFactory read FThreadPooledFactory write SetThreadPooledFactory;
    property RejectedExecutionHandler: IRejectedExecutionHandler read FRejectedExecutionHandler write SetRejectedExecutionHandler;
    property KeepAliveTime : Integer read FKeepAliveTime write SetKeepAliveTime;
    property CorePoolSize : Integer read FCorePoolSize write SetCorePoolSize;
    property MaximumPoolSize : Integer read FMaximumPoolSize write SetMaximumPoolSize;
    property AllowsCoreThreadTimeOut: boolean read FAllowCoreThreadTimeOut write SetAllowCoreThreadTimeOut;
    property PoolSize: integer read FPoolSize;
    property LargestPoolSize: integer read GetLargestPoolSize;
    property Queue: TInterfaceBlockingQueue read FWorkQueue;
    property OwnedQueue: boolean read FOwnedQueue write FOwnedQueue default false; 
  end;

  TThreadPooled = class(TCustomThread)
  private
    FWorker: TWorker;
    FException: TObject;
    procedure DoHandleException;
  protected
    procedure HandleException; virtual;
    procedure Execute; override;
  public
    constructor Create(const AWorker: TWorker);
    destructor Destroy(); override;
  end;

  TDefaultThreadPooledFactory = class(TInterfacedObject, IThreadPooledFactory)
  public
    constructor Create();
    destructor Destroy(); override;

    function CreateThread(const AWorker: TWorker): TThreadPooled;
  end;

  IRejectedExecutionHandler = interface
    ['{B75598D2-ABC4-42BF-92E9-B7207318603D}']
    procedure RejectedExecution(const ATask: IRunnable; const APool: TThreadPoolExecutor);
  end;

  TCallerRunsPolicy = class(TInterfacedObject, IRejectedExecutionHandler)
  public
    procedure RejectedExecution(const ATask: IRunnable; const APool: TThreadPoolExecutor);
  end;

  TAbortPolicy = class(TInterfacedObject, IRejectedExecutionHandler)
  public
    procedure RejectedExecution(const ATask: IRunnable; const APool: TThreadPoolExecutor);
  end;

  TDiscardPolicy = class(TInterfacedObject, IRejectedExecutionHandler)
  public
    procedure RejectedExecution(const ATask: IRunnable; const APool: TThreadPoolExecutor);
  end;

  TDiscardOldestPolicy = class(TInterfacedObject, IRejectedExecutionHandler)
  public
    procedure RejectedExecution(const ATask: IRunnable; const APool: TThreadPoolExecutor);
  end;

  TWorker = class
  strict private var
    FThread:TThreadPooled;
    FThreadPool:TThreadPoolExecutor;
    FLock: TCriticalSection;
    FFirstTask: IRunnable;
    FCompletedTasks: integer;
  private
    procedure SetThread(const Value: TThreadPooled);
    procedure RunTask(const ATask: IRunnable);
  public
    constructor Create(const AThreadPool: TThreadPoolExecutor; const AFirstTask: IRunnable); overload;
    constructor Create(const AFirstTask: IRunnable); overload;
    destructor Destroy(); override;

    function IsActive(): boolean;
    procedure InterruptIfIdle;
    procedure InterruptNow;

    procedure Run();

    property ThreadPool: TThreadPoolExecutor read FThreadPool write FThreadPool;
    property Thread: TThreadPooled read FThread write SetThread;
    property CompletedTasks: integer read FCompletedTasks;
  end;

implementation

uses
  Windows, Exceptions, Messages;

{ TThreadPool }

function TThreadPoolExecutor.AddIfUnderCorePoolSize(const AFirstTask: IRunnable): boolean;
var
  LThread: TThread;
begin
  LThread := nil;       
  FLock.Acquire();
  try
    if (FPoolSize < FCorePoolSize) then LThread := AddThread(AFirstTask);
  finally
    FLock.Release();
  end;
  if not Assigned(LThread) then begin
    Result := false;
  end else begin
    LThread.Resume();
    Result := true;
  end;
end;

function TThreadPoolExecutor.AddIfUnderMaximumPoolSize(
  const AFirstTask: IRunnable): integer;
var
  LThread: TThread;
  LStatus: Integer;
  LNext: IRunnable;
begin
  LThread := nil;
  LStatus := 0;
  FLock.Acquire();
  try
    if (FPoolSize < FMaximumPoolSize) then begin
      LNext := IRunnable(FWorkQueue.Poll());
      if not Assigned(LNext) then begin
        LNext := AFirstTask;
        LStatus := 1;
      end else begin
        LStatus := -1;
      end;
      LThread := AddThread(LNext);
    end;
  finally
    FLock.Release();
  end;
  if not Assigned(LThread) then begin
    LStatus := 0;
  end else begin
    LThread.Resume();
  end;
  Result := LStatus;
end;

function TThreadPoolExecutor.AddThread(const AFirstTask: IRunnable): TThread;
var
  LWorker: TWorker;
  LThread: TThreadPooled;
begin
  Result := nil;
  if (FRunState = STATE_TERMINATED) then begin
    Exit;
  end;
  LWorker := TWorker.Create(Self, AFirstTask);
  LThread := FThreadPooledFactory.CreateThread(LWorker);
  if Assigned(LThread) then begin
    LWorker.Thread := LThread;
    FWorkers.Add(LWorker);
    Inc(FPoolSize);
    if (FPoolSize > FLargestPoolSize) then FLargestPoolSize := FPoolSize;
    Result := LThread;
  end;
end;

function TThreadPoolExecutor.AwaitTermination(const ATimeout: int64): boolean;
const
  PERCENTAGE = 10;
var
  LTimeOut: Integer;
  LPartiality: Integer;
begin
  Result := false;
  LTimeOut := ATimeout;
  FLock.Acquire();
  try
    LPartiality := Round(PERCENTAGE * LTimeOut / 100);
    while true do begin
      if (FRunState = STATE_TERMINATED) then begin
        Result := true;
        Break;
      end;
      if (LTimeOut <= 0) then begin
        Result := false;
        Break;
      end;

      //Sleeps PERCENTAGE of total timeout at a time  
      SleepEx(LPartiality, true);

      LTimeOut := LTimeOut - LPartiality;
    end;
  finally
    FLock.Release();
  end;
end;

procedure TThreadPoolExecutor.AfterExecute(const ATask: IRunnable;
  const AException: Exception);
begin
//
end;

procedure TThreadPoolExecutor.BeforeExecute(const AThread: TThread; const ATask: IRunnable);
begin
//
end;

constructor TThreadPoolExecutor.Create(const ACorePoolSize, AMaximumPoolSize,
  AKeepAliveTime: integer; const AWorkQueue: TInterfaceBlockingQueue);
begin
  Create(ACorePoolSize, AMaximumPoolSize, AKeepAliveTime, AWorkQueue, TDefaultThreadPooledFactory.Create());
end;

constructor TThreadPoolExecutor.Create(const ACorePoolSize, AMaximumPoolSize,
  AKeepAliveTime: integer; const AWorkQueue: TInterfaceBlockingQueue;
  const AThreadFactory: IThreadPooledFactory);
begin
  Create(ACorePoolSize, AMaximumPoolSize, AKeepAliveTime, AWorkQueue,
         AThreadFactory,
         TAbortPolicy.Create());
end;

constructor TThreadPoolExecutor.Create(const ACorePoolSize, AMaximumPoolSize,
  AKeepAliveTime: integer; const AWorkQueue: TInterfaceBlockingQueue;
  const AThreadFactory: IThreadPooledFactory;
  const ARejectedExecutionHandler: IRejectedExecutionHandler);
begin
  if (ACorePoolSize < 0)
      or (AMaximumPoolSize <= 0)
      or (AMaximumPoolSize < ACorePoolSize)
      or (AKeepAliveTime < 0) then raise EInvalidParameters.Create();

  if not Assigned(AWorkQueue)
      or not Assigned(AThreadFactory)
      or not Assigned(ARejectedExecutionHandler) then raise ENullPointer.Create;
                                    
  inherited Create();
  FCorePoolSize := ACorePoolSize;
  FMaximumPoolSize := AMaximumPoolSize;
  FKeepAliveTime := AKeepAliveTime;
  FWorkQueue := AWorkQueue;
  FThreadPooledFactory := AThreadFactory;
  FRejectedExecutionHandler := ARejectedExecutionHandler;

  FWorkers:= TObjectList.Create(true);
  FLock := TCriticalSection.Create;
  FPoolSize := 0;
  FAllowCoreThreadTimeOut:= false;
  FLargestPoolSize:= 0;
  FRunState:= 0;
  FCompletedTaskCount:= 0;
  FOwnedQueue := false;
end;

destructor TThreadPoolExecutor.Destroy;
begin
  Shutdown;
  FWorkers.Free;
  FLock.Free;
  if FOwnedQueue then FreeAndNil(FWorkQueue);
  inherited;
end;

procedure TThreadPoolExecutor.Execute(const ATask: IRunnable);
var
  LStatus: integer;
begin
  if not Assigned(ATask) then raise ENullPointer.Create;

  while true do begin
    if (FRunState <> STATE_RUNNING) then begin
      Reject(ATask);
      Break;
    end;

    if (FPoolSize < FCorePoolSize) and AddIfUnderCorePoolSize(ATask) then begin
      Break;
    end;

    if (FWorkQueue.Offer(ATask)) then Break;

    LStatus := AddIfUnderMaximumPoolSize(ATask);
    if (LStatus > 0) then Exit;
    if (LStatus = 0) then begin
      Reject(ATask);
      Break;
    end;
  end;
end;

function TThreadPoolExecutor.GetActiveCount: integer;
var
  LCount: Integer;
  LWorker: Pointer;
begin
  FLock.Acquire();
  try
    LCount := 0;
    for LWorker in FWorkers do begin
      if (TWorker(LWorker)).IsActive() then begin
        Inc(LCount);
      end;
    end;
    Result := LCount;
  finally
    FLock.Release();
  end;
end;

function TThreadPoolExecutor.GetCompletedTaskCount: integer;
var
  LCompleted: Integer;
  LWorker: Pointer;
begin
  FLock.Acquire();
  try
    LCompleted := FCompletedTaskCount;
    for LWorker in FWorkers do begin
      LCompleted := LCompleted + TWorker(LWorker).CompletedTasks;
    end;
    Result := LCompleted;
  finally
    FLock.Release();
  end;
end;

function TThreadPoolExecutor.GetLargestPoolSize: integer;
begin
  FLock.Acquire();
  try
    Result := FLargestPoolSize;
  finally
    FLock.Release();
  end;
end;

function TThreadPoolExecutor.GetTask: IRunnable;
var
  LTimeOut: Integer;
  LTask: IRunnable;
begin
  while true do begin
    try
      case FRunState of
        STATE_RUNNING: begin
          if (FPoolSize <= FCorePoolSize) and (not FAllowCoreThreadTimeOut)  then begin
            Result := IRunnable(FWorkQueue.Take());
            Exit;
          end;

          LTimeOut := FKeepAliveTime;
          if (LTimeOut <= 0) then begin
            Result := nil;
            Exit;
          end;

          LTask := IRunnable(FWorkQueue.Poll(LTimeOut));
          if Assigned(LTask) then begin
            Result := LTask;
            Exit;
          end;

          if (FPoolSize > FCorePoolSize) or (FAllowCoreThreadTimeOut) then begin
            Result := nil; //timed out
            Exit;
          end;

          Result := nil;
          Break;
        end;
        STATE_SHUTDOWN: begin
          LTask := IRunnable(FWorkQueue.Poll());
          if Assigned(LTask) then begin
            Result := LTask;
            Exit;
          end;

          if FWorkQueue.IsEmpty then begin
            InterruptIdleWorkers();
            Result := nil;
            Break;
          end;

          Result := IRunnable(FWorkQueue.Take());
        end;
        STATE_STOP: begin
          Result := nil;
          Exit;
        end;
        else begin
          Assert(false, 'Invalid state.');
        end;
      end;
    except
      on E: EInterrupted do begin
        //
      end else raise;
    end;
  end;
end;

function TThreadPoolExecutor.GetTaskCount: integer;
var
  LCompleted: integer;
  LWorker: Pointer;
begin
  FLock.Acquire();
  try
    LCompleted := FCompletedTaskCount;
    for LWorker in FWorkers do begin
      LCompleted := LCompleted + TWorker(LWorker).CompletedTasks;
      if (TWorker(LWorker).IsActive) then Inc(LCompleted);
    end;
    Result := LCompleted + FWorkQueue.Count;
  finally
    FLock.Release();
  end;
end;

procedure TThreadPoolExecutor.InterruptIdleWorkers;
var
  LItem: Pointer;
begin
  FLock.Acquire();
  try
    for LItem in FWorkers do begin
      TWorker(LItem).InterruptIfIdle();  
    end;
  finally
    FLock.Release();
  end;
end;

function TThreadPoolExecutor.IsShutdown: boolean;
begin
  Result := FRunState <> STATE_RUNNING;
end;

function TThreadPoolExecutor.IsTerminated: boolean;
begin
  Result := FRunState = STATE_TERMINATED;
end;

function TThreadPoolExecutor.IsTerminating: boolean;
begin
  Result := FRunState = STATE_STOP;
end;

function TThreadPoolExecutor.PrestartAllCoreThreads: integer;
var
  LCount: Integer;
begin
  LCount := 0;
  while (AddIfUnderCorePoolSize(nil)) do Inc(LCount);
  Result := LCount;
end;

function TThreadPoolExecutor.PrestartCoreThread: boolean;
begin
  Result := AddIfUnderCorePoolSize(nil);
end;

procedure TThreadPoolExecutor.Reject(const ATask: IRunnable);
begin
  FRejectedExecutionHandler.RejectedExecution(ATask, Self);
end;

function TThreadPoolExecutor.Remove(const ATask: IRunnable): boolean;
begin
  Result := FWorkQueue.Remove(ATask);
end;

procedure TThreadPoolExecutor.SetAllowCoreThreadTimeOut(const Value: boolean);
begin
  if (Value and (FKeepAliveTime <= 0)) then begin
    raise ECoreThreadNonZeroKeepAliveTime.Create();
  end;
  FAllowCoreThreadTimeOut := Value;
end;

procedure TThreadPoolExecutor.SetCorePoolSize(val: Integer);
var
  LExtra: Integer;
  LSize: Integer;
  LThread: TThread;
  LIx: integer;
begin
  if (val < 0) then raise EInvalidParameters.Create();

  FLock.Acquire();
  try
    LExtra := FCorePoolSize - Val;
    FCorePoolSize := Val;
    if (LExtra < 0) then begin
      LSize := FWorkQueue.Count;
      Inc(LExtra);
      Dec(LSize);
      while (LExtra < 0) and (LSize > 0) and (FPoolSize < val) do begin
        LThread := AddThread(nil);
        if not Assigned(LThread) then begin
          LThread.Resume();
        end else begin
          Break;
        end;
        Inc(LExtra);
        Dec(LSize);
      end;
    end else if (LExtra > 0) and (FPoolSize > val) then begin
      LIx := 0;
      Dec(LExtra);
      while (LIx < FWorkers.Count) and (LExtra > 0) and (FPoolSize > Val)
          and (FWorkQueue.RemainingCapacity = 0) do begin
            (FWorkers[Lix] as TWorker).InterruptIfIdle();
            Dec(LExtra);
      end;
    end;                                                 
  finally
    FLock.Release();
  end;
end;

procedure TThreadPoolExecutor.SetKeepAliveTime(val: Integer);
begin
  if (val < 0) then raise EIllegalArgument.Create();
  if (val = 0) and AllowsCoreThreadTimeOut then raise ECoreThreadNonZeroKeepAliveTime.Create();
  FKeepAliveTime := val;
end;

procedure TThreadPoolExecutor.SetMaximumPoolSize(val: Integer);
var
  LExtra: Integer;
  LIx: Integer;
begin
  if (val <= 0) or (val < FCorePoolSize) then raise EIllegalArgument.Create();
  FLock.Acquire();
  try
    LExtra := FMaximumPoolSize - val;
    FMaximumPoolSize := val;
    if (LExtra > 0) and (FPoolSize > val) then begin
      LIx := 0;
      while (LIx < FWorkers.Count) and (LExtra > 0) and (FPoolSize > Val)
          and (FWorkQueue.RemainingCapacity = 0) do begin
            (FWorkers[Lix] as TWorker).InterruptIfIdle();
            Dec(LExtra);
      end;
    end;
  finally
    FLock.Release();
  end;
end;

procedure TThreadPoolExecutor.SetRejectedExecutionHandler(
  const Value: IRejectedExecutionHandler);
begin
  if not Assigned(Value) then raise ENullPointer.Create();
  FRejectedExecutionHandler := Value;
end;

procedure TThreadPoolExecutor.SetThreadPooledFactory(const Value: IThreadPooledFactory);
begin
  if not Assigned(Value) then raise ENullPointer.Create;
  FThreadPooledFactory := Value;
end;

procedure TThreadPoolExecutor.Shutdown;
var
  LFullyTerminated: Boolean;
  LState: Integer;
  LWorker: Pointer;
begin
  LFullyTerminated := false;
  FLock.Acquire();
  try
    if (FWorkers.Count > 0) then begin
      LState := FRunState;
      if (LState = STATE_RUNNING) then FRunState := STATE_SHUTDOWN;
      try
        for LWorker in FWorkers do begin
          TWorker(LWorker).InterruptIfIdle;
        end;
      except
        on E: Exception do begin
          FRunState := LState;
          raise;
        end;
      end;
    end else begin
      LFullyTerminated := true;
      FRunState := STATE_TERMINATED;
      { TODO : Leave all lock.acquire }
    end;
  finally
    FLock.Release();
  end;
  if LFullyTerminated then Terminated;
end;

function TThreadPoolExecutor.ShutdownNow: TRunnableArray;
var
  LFullyTerminated: Boolean;
  LState: Integer;
  LWorker: Pointer;
  LList: TInterfaceArray;
  I: Integer;
begin
  SetLength(Result, 0);
  LFullyTerminated := false;
  FLock.Acquire();
  try
    if (FWorkers.Count > 0) then begin
      LState := FRunState;
      if (LState <> STATE_TERMINATED) then FRunState := STATE_STOP;
      try
        for LWorker in FWorkers do begin
          TWorker(LWorker).InterruptNow();
        end;
      except
        on E: Exception do begin
          FRunState := LState;
          raise;
        end;
      end;
    end else begin
      LFullyTerminated := true;
      FRunState := STATE_TERMINATED;
      { TODO : Leave all lock.acquire }
    end;
  finally
    FLock.Release();
  end;
  if LFullyTerminated then Terminated;

  LList := FWorkQueue.ToArray();
  SetLength(Result, Length(LList));
  for I := Low(LList) to High(LList) do begin
    Result[I] := IRunnable(LList[I]);
  end;
end;

procedure TThreadPoolExecutor.Terminated;
begin
  { TODO : Implement }
end;

procedure TThreadPoolExecutor.WorkerDone(const AWorker: TWorker);
var
  LState: Integer;
  LThread: TThread;
begin
  FLock.Acquire();
  try
    FCompletedTaskCount := FCompletedTaskCount + AWorker.CompletedTasks;
    FWorkers.Remove(AWorker);
    Dec(FPoolSize);
    if (FPoolSize > 0) then Exit;

    LState := FRunState;
    Assert(LState <> STATE_TERMINATED, 'Unexpected state.');

    if (LState <> STATE_STOP) then begin
      if not FWorkQueue.IsEmpty then begin
        LThread := AddThread(nil);
        if Assigned(LThread) then begin
          LThread.Resume;
          Exit;
        end;
      end;

      if (LState = STATE_RUNNING) then Exit;
    end;
    
    //Leave all
    { TODO : Leave all lock.acquire }
    FRunState := STATE_TERMINATED;
  finally
    FLock.Release();
  end;

  Assert(FRunState = STATE_TERMINATED, 'Unexpected state');

  Terminated;
end;

{ TDefaultThreadPooledFactory }

constructor TDefaultThreadPooledFactory.Create;
begin
  inherited;
end;

function TDefaultThreadPooledFactory.CreateThread(const AWorker: TWorker): TThreadPooled;
begin
  Result := TThreadPooled.Create(AWorker);
end;

destructor TDefaultThreadPooledFactory.Destroy;
begin
  inherited;
end;

{ TWorker }

constructor TWorker.Create(const AFirstTask: IRunnable);
begin
  Create(nil, AFirstTask);  
end;

constructor TWorker.Create(const AThreadPool: TThreadPoolExecutor;
  const AFirstTask: IRunnable);
begin
  inherited Create();
  FThreadPool := AThreadPool;
  FFirstTask := AFirstTask;
  FLock := TCriticalSection.Create;
  FCompletedTasks := 0;
  FThread := nil;
end;

destructor TWorker.Destroy;
begin
  FFirstTask := nil;
  FLock.Free;
  inherited;
end;

procedure TWorker.InterruptIfIdle;
begin
  if FLock.TryEnter then begin
    try
      //If not locked, so there's no work being done
      FThread.Interrupt;
    finally
      FLock.Leave;
    end;
  end;
end;

procedure TWorker.InterruptNow;
begin
  FThread.Interrupt;
end;

function TWorker.IsActive: boolean;
begin
  Result := true;
  if FLock.TryEnter then begin
    FLock.Leave;
    Result := false;
  end;
end;

procedure TWorker.Run;
var
  LTask: IRunnable;
begin
  LTask := FFirstTask;
  try
    FFirstTask := nil;
    if not Assigned(LTask) then begin
      LTask := FThreadPool.GetTask();
    end;
    while (Assigned(LTask)) do begin
      RunTask(LTask);
      LTask := nil; //Helps garbage collector, preventing a non-destruction by core thread waiting forever
      LTask := FThreadPool.GetTask();
    end;   
  finally
    FThreadPool.WorkerDone(Self);
  end;
end;

procedure TWorker.RunTask(const ATask: IRunnable);
var
  LRan: Boolean;
begin
  FLock.Acquire();
  try
    if (FThreadPool.FRunState <> TThreadPoolExecutor.STATE_STOP)
        and (FThread.Interrupted)
        and (FThreadPool.FRunState = TThreadPoolExecutor.STATE_STOP) then begin
          //It has been interrupted but never entered in special state to handle interruption
          FThread.Interrupt;
          SleepEx(1, true);
        end;

    LRan := false;
    FThreadPool.BeforeExecute(FThread, ATask);
    try
      ATask.Run;
      LRan := true;
      FThreadPool.AfterExecute(ATask, nil);
      Inc(FCompletedTasks);
    except
      on E: Exception do begin
        if not LRan then FThreadPool.AfterExecute(ATask, E);
        raise; 
      end;
    end;
  finally
    FLock.Release();
  end;
end;

procedure TWorker.SetThread(const Value: TThreadPooled);
begin
  FThread := Value;
  FThread.FreeOnTerminate := true;
end;

{ TThreadPooled }

constructor TThreadPooled.Create(const AWorker: TWorker);
begin
  inherited Create(true);
  FWorker := AWorker;
end;

destructor TThreadPooled.Destroy;
begin
  inherited;
end;

procedure TThreadPooled.DoHandleException;
begin
  if GetCapture <> 0 then SendMessage(GetCapture, WM_CANCELMODE, 0, 0);
  SysUtils.ShowException(FException, nil);
end;

procedure TThreadPooled.Execute;
begin
  inherited;
  try
    FWorker.Run();
  except
    HandleException;
  end;
end;

procedure TThreadPooled.HandleException;
begin
  FException := ExceptObject;
  try
    if (FException is EAbort) then Exit;
    Synchronize(DoHandleException);
  finally
    FException := nil;
  end;
end;

{ TCallerRunsPolicy }

procedure TCallerRunsPolicy.RejectedExecution(const ATask: IRunnable;
  const APool: TThreadPoolExecutor);
begin
  if not APool.IsShutdown then ATask.Run();
end;

{ TAbortPolicy }

procedure TAbortPolicy.RejectedExecution(const ATask: IRunnable;
  const APool: TThreadPoolExecutor);
begin
  raise ERejectecExecution.Create();
end;

{ TDiscardPolicy }

procedure TDiscardPolicy.RejectedExecution(const ATask: IRunnable;
  const APool: TThreadPoolExecutor);
begin
  //
end;

{ TDiscardOldestPolicy }

procedure TDiscardOldestPolicy.RejectedExecution(const ATask: IRunnable;
  const APool: TThreadPoolExecutor);
begin
  if not APool.IsShutdown then begin
    APool.Queue.Poll();
    APool.Execute(ATask);
  end;
end;

end.
