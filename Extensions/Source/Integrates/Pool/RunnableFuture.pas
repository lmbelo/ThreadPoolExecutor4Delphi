{*******************************************************}
{                                                       }
{               ThreadPoolExecutor4Delphi               }
{                                                       }
{           Author: Lucas Moura Belo - LMBelo           }
{           Date: 04/07/2019                            }
{           Belo Horizonte - MG - Brazil                }
{                                                       }
{*******************************************************}

unit RunnableFuture;

interface

uses
  Runnable;

type
  ITaskFuture = interface(IRunnable)
    ['{201A1063-24E5-4453-B3BD-5270AE18BE17}']
    procedure Run();
  end;

implementation

end.                             
