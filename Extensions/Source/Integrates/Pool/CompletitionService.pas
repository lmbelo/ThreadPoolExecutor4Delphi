{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit CompletitionService;

interface

uses
  Callable, Future, ExecutorService, Runnable;

type
  ICompletitionService = interface
    ['{3B176084-CE9F-464A-BB8E-B3314FB43516}']
    function Submit(const ACallable: ICallable): IFuture; overload;
    function Submit(const ATask: IRunnable; var AResult: pointer): IFuture; overload;
    function Take(): IFuture;
    function Poll(): IFuture; overload;
    function Poll(const ATimeOut: integer): IFuture; overload;
  end;

implementation

end.
