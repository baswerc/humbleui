package org.humbleui
{
  public interface IRemoteObjectProxy
  {
    function set resultHandler(value:Function):void;
    function set faultHandler(value:Function):void;
  }
}