{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit Future;

interface

uses
  Classes;

type
  IFuture = interface
    ['{7D358C66-F7FD-4A90-9555-7772433C35B5}']
    function Cancel(const AInterruptIfRunning: boolean): boolean;
    function IsCancelled(): boolean;
    function IsDone(): boolean;
    procedure GetResult(out AResult: pointer); overload;
    procedure GetResult(const ATimeOut: Int64; out AResult: pointer); overload;
  end;

  TFutureList = class(TInterfaceList)
  end;

implementation

end.
