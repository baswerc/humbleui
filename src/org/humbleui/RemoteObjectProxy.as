package org.humbleui
{
  import flash.events.Event;
  import flash.utils.Proxy;
  import flash.utils.flash_proxy;
  
  import mx.rpc.AbstractOperation;
  import mx.rpc.AsyncToken;
  import mx.rpc.events.FaultEvent;
  import mx.rpc.events.ResultEvent;
  import mx.rpc.remoting.RemoteObject;
  import mx.utils.UIDUtil;
  
  use namespace flash.utils.flash_proxy;

  public dynamic class RemoteObjectProxy extends Proxy
  {
    private var destination:String;
    private var remoteObjectRepo:RemoteObjectRepository;
    private var defaultFaultHandler:Function;
    private var defaultResultHandler:Function;
    
    private var remoteObjects:Object = new Object();
    
    private var _lastResultHandler:Function;
    private var _lastFaultHandler:Function;
    
    public function RemoteObjectProxy(destination:String, remoteObjectRepo:RemoteObjectRepository, 
      defaultFaultHandler:Function=null, defaultResultHandler:Function=null)
    {
      this.destination = destination;
      this.remoteObjectRepo = remoteObjectRepo;
      this.defaultFaultHandler = defaultFaultHandler;
      this.defaultResultHandler = defaultResultHandler;
    }
    
    public function set resultHandler(value:Function):void
    {
      _lastResultHandler = value;
    }
    
    public function set faultHandler(value:Function):void
    {
      _lastFaultHandler = value;
    }
    
    public function getRemoteObject(token:AsyncToken):RemoteObject
    {
      if (remoteObjects[token.remoteObjectProxyUid] != undefined)
      {
        return RemoteObject(remoteObjects[token.remoteObjectProxyUid]);
      }
      else
      {
        return null;
      }
    }
    
    public function cancelRequest(token:AsyncToken):void
    {
      if (remoteObjects[token.remoteObjectProxyUid] != undefined)
      {
        try
        {
          var remoteObject:RemoteObject = RemoteObject(remoteObjects[token.remoteObjectProxyUid]);
          if (token.remoteObjectProxyFaultHandler != undefined)
          {
            remoteObject.removeEventListener(FaultEvent.FAULT, token.remoteObjectProxyFaultHandler);
          }
          remoteObject.disconnect();
        }
        finally
        {
          delete remoteObjects[token.uid];
        }
      }
      else
      {
        token = null;
      }
    }
    
    flash_proxy override function callProperty(name:*, ... rest):*
    {
      var remoteObj:RemoteObject = remoteObjectRepo.createRemoteObject(destination);
      if (_lastResultHandler != null)
      {
        remoteObj.addEventListener(ResultEvent.RESULT, _lastResultHandler);
      }
      else if (defaultResultHandler != null)
      {
        remoteObj.addEventListener(ResultEvent.RESULT, defaultResultHandler);
      }
      
      var faultHandler:Function = null;
      if (_lastFaultHandler != null)
      {
        faultHandler = _lastFaultHandler;
      }
      else if (defaultFaultHandler != null)
      {
        faultHandler = defaultFaultHandler;
      }
      
      if (faultHandler != null)
      {
        remoteObj.addEventListener(FaultEvent.FAULT, faultHandler);
      }
      
      
      _lastResultHandler = null;
      _lastFaultHandler = null;
      
      var operation:AbstractOperation = remoteObj.getOperation(name);
      var sendFunction = operation.send;
      var uid:String = UIDUtil.createUID();
      
      remoteObjects[uid] = remoteObj;
      var clearHandler:Function = function(event:Event):void
      {
        delete remoteObjects[uid];
      };
      remoteObj.addEventListener(FaultEvent.FAULT, clearHandler);
      remoteObj.addEventListener(ResultEvent.RESULT, clearHandler);
      
      var token:AsyncToken = sendFunction.apply(operation, rest);
      token.remoteObjectProxyUid = uid;
      if (faultHandler != null)
      {
        token.remoteObjectProxyFaultHandler = faultHandler
      }
      token.remoteObjectProxy = this;
      return token;
    }
  }
}