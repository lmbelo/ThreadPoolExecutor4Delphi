{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit ExecutorCompletitionService;

interface

uses
  CompletitionService, FutureTask, RunnableFuture, Future, ExecutorService, 
  AbstractExecutorService, BlockingQueue, Callable, Executor, Runnable;

type
  TExecutorCompletitionService = class(TInterfacedObject, ICompletitionService)
  private type
    TQueueingFuture = class(TFutureTask)
    private
      FParent: TExecutorCompletitionService;
      FTask: IFuture;
    protected
      procedure Done(); override;
    public
      constructor Create(const AParent: TExecutorCompletitionService; const ATask: ITaskFuture);
    end;
  private
    FExecutor: IExecutor;
    FAES: TAbstractExecutorService;
    FCompletitionQueue: TInterfaceBlockingQueue;
  private
    function NewTaskFor(const ACallable: ICallable): ITaskFuture; overload;
    function NewTaskFor(const ATask: IRunnable; var AResult: pointer): ITaskFuture; overload;
  public
    constructor Create(const AExecutor: IExecutor);

    function Submit(const ACallable: ICallable): IFuture; overload;
    function Submit(const ATask: IRunnable; var AResult: pointer): IFuture; overload;
    function Take(): IFuture;
    function Poll(): IFuture; overload;
    function Poll(const ATimeOut: integer): IFuture; overload;
  end;

implementation

uses
  Exceptions;

{ TExecutorCompletitionService.TQueueingFuture }

constructor TExecutorCompletitionService.TQueueingFuture.Create(
  const AParent: TExecutorCompletitionService; const ATask: ITaskFuture);
var
  LNil: pointer;
begin
  LNil := nil;
  inherited Create(ATask as IRunnable, LNil);
  FParent := AParent;
  FTask := ATask as IFuture;
end;

procedure TExecutorCompletitionService.TQueueingFuture.Done;
begin
  FParent.FCompletitionQueue.Add(FTask);
end;

{ TExecutorCompletitionService }

function TExecutorCompletitionService.NewTaskFor(
  const ACallable: ICallable): ITaskFuture;
begin
  if not Assigned(FAES) then
    Result := TFutureTask.Create(ACallable)
  else
    Result := FAES.NewTaskFor(ACallable);
end;

constructor TExecutorCompletitionService.Create(const AExecutor: IExecutor);
begin
  if not Assigned(AExecutor) then raise ENullPointer.Create();
  FExecutor := AExecutor;
  if (AExecutor.GetAsObject() is TAbstractExecutorService) then begin
    FAES := (AExecutor.GetAsObject() as TAbstractExecutorService)
  end else begin
    FAES := nil
  end;
  FCompletitionQueue := TInterfaceBlockingQueue.Create()
end;

function TExecutorCompletitionService.NewTaskFor(const ATask: IRunnable;
  var AResult: pointer): ITaskFuture;
begin
  if not Assigned(FAES) then
    Result := TFutureTask.Create(ATask, AResult)
  else
    Result := FAES.NewTaskFor(ATask, AResult);
end;

function TExecutorCompletitionService.Poll(const ATimeOut: integer): IFuture;
begin
  Result := FCompletitionQueue.Poll(ATimeOut) as IFuture;
end;

function TExecutorCompletitionService.Poll: IFuture;
begin
  Result := FCompletitionQueue.Poll() as IFuture;
end;

function TExecutorCompletitionService.Submit(const ATask: IRunnable;
  var AResult: pointer): IFuture;
var
  LTask: ITaskFuture;
begin
  if not Assigned(ATask) then raise ENullPointer.Create();
  LTask := NewTaskFor(ATask, AResult);
  FExecutor.Execute(TQueueingFuture.Create(Self, LTask));
  Result := LTask as IFuture;
end;

function TExecutorCompletitionService.Submit(
  const ACallable: ICallable): IFuture;
var
  LTask: ITaskFuture;
begin
  if not Assigned(ACallable) then raise ENullPointer.Create();
  LTask := NewTaskFor(ACallable);
  FExecutor.Execute(TQueueingFuture.Create(Self, LTask));
  Result := LTask as IFuture;
end;

function TExecutorCompletitionService.Take: IFuture;
begin
  Result := FCompletitionQueue.Take() as IFuture;
end;

end.
