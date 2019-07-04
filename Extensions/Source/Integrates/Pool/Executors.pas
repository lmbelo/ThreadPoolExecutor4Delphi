{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit Executors;

interface

uses
  ExecutorService, Callable, Runnable;

type
  TExecutors = class
  private
    {$HINTS OFF}
    constructor Create();
    {$HINTS ON}
  public
    //Make sure threadpoolexecutor has shutdown before destruction
    class function CreateFixedThreadPool(const ANThreads: integer): IExecutorService; static;
    class function Callable(const ATask: IRunnable; out AResult: pointer): ICallable; static;
  end;

implementation

uses
  Exceptions, ThreadPoolExecutor, BlockingQueue;

type
  TRunnableAdapter = class(TInterfacedObject, ICallable)
  private
    FTask: IRunnable;
    FResult: pointer;
  public
    constructor Create(const ATask: IRunnable; out AResult: pointer);  
    procedure Call(out AResult: pointer);
  end;

{ TExecutors }

class function TExecutors.Callable(const ATask: IRunnable; out AResult: pointer): ICallable;
begin
  if not Assigned(ATask) then raise ENullPointer.Create();
  Result := TRunnableAdapter.Create(ATask, AResult);
end;

constructor TExecutors.Create;
begin
end;

class function TExecutors.CreateFixedThreadPool(
  const ANThreads: integer): IExecutorService;
var
  LExecutor: TThreadPoolExecutor;
begin
  LExecutor := TThreadPoolExecutor.Create(ANThreads,
                 ANThreads,
                 0,
                 TInterfaceBlockingQueue.Create(MaxInt));
  LExecutor.OwnedQueue := true;
  Result := LExecutor;
end;

{ TTaskAdapter }

procedure TRunnableAdapter.Call(out AResult: pointer);
begin
  FTask.Run();
  AResult := FResult;
end;

constructor TRunnableAdapter.Create(const ATask: IRunnable; out AResult: pointer);
begin
  FTask := ATask;
  AResult := FResult;
end;

end.
