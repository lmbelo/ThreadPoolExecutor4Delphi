{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit Executor;

interface

uses
  ExecutorService, Runnable;

type
  IExecutor = interface
    ['{57A71D13-FDB5-4536-B155-2ED136C9AE00}']
    function GetAsObject: TObject;
    procedure Execute(const ACommand: IRunnable);
  end;

implementation

end.
