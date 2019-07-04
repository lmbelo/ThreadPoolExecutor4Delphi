{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit ExecutorService;

interface

uses
  Future, Callable, Runnable;

type
  IExecutorService = interface
    ['{8E517AF7-5086-4C56-8CF4-79B3F47AF275}']
    procedure Shutdown;
    function ShutdownNow: TRunnableArray;
    function IsShutdown: boolean;
    function IsTerminated: boolean;
    function AwaitTermination(const ATimeOut: int64): boolean;

    function Submit(const ATask: ICallable): IFuture; overload;
    function Submit(const ATask: IRunnable; var AResult: pointer): IFuture; overload;
    function Submit(const ATask: IRunnable): IFuture; overload;
    function InvokeAll(const ATasks: TCallableList): TFutureList; overload;
    function InvokeAll(const ATasks: TCallableList; ATimeOut: Int64): TFutureList; overload;
    procedure InvokeAny(const ATasks: TCallableList; out AResult: pointer); overload;
    procedure InvokeAny(const ATask: TCallableList; ATimeOut: Int64; out AResult: pointer); overload;
  end;

implementation

end.
