package org.humbleui
{
  import flash.events.Event;
  import flash.events.IEventDispatcher;
  
  import mx.core.Application;

  public class StageEventDispatcher implements IEventDispatcher
  {
    var application:Application;
    
    public function StageEventDispatcher(application:Application)
    {
      this.application = application;
    }

    public function addEventListener(type:String, listener:Function, useCapture:Boolean=false, priority:int=0, useWeakReference:Boolean=false):void
    {
    }
    
    public function removeEventListener(type:String, listener:Function, useCapture:Boolean=false):void
    {
    }
    
    public function dispatchEvent(event:Event):Boolean
    {
      return false;
    }
    
    public function hasEventListener(type:String):Boolean
    {
      return false;
    }
    
    public function willTrigger(type:String):Boolean
    {
      return false;
    }
    
    private function get dispatcher():IEventDispatcher
    {
      return (application.stage == null) ? application : application.stage;
    }
  }
}