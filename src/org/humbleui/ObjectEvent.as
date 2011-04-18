package org.humbleui
{
  import flash.events.Event;
  
  public class ObjectEvent extends Event
  {
    private var _data:Object;
    
    public function ObjectEvent(type:String, data:Object, bubbles:Boolean=true, canceable:Boolean=false)
    {
      super(type, bubbles, canceable);
      _data = data;
    }
    
    public function get data():Object
    {
      return _data;
    }

  }
}