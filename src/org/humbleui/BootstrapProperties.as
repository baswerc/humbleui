/*
 * Copyright 2009 Corey Baswell 
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); 
 * you may not use this file except in compliance with the License. 
 * You may obtain a copy of the License at 
 * 
 * http://www.apache.org/licenses/LICENSE-2.0 
 *
 * Unless required by applicable law or agreed to in writing, software 
 * distributed under the License is distributed on an "AS IS" BASIS, 
 * WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. 
 * See the License for the specific language governing permissions and 
 * limitations under the License.
 */ 
 package org.humbleui
{
  import flash.events.Event;
  import flash.events.EventDispatcher;
  import flash.events.IOErrorEvent;
  import flash.net.URLLoader;
  import flash.net.URLRequest;
  
  import mx.controls.Alert;
  import mx.utils.StringUtil;
  
  [Event(name="complete", type="flash.events.Event")]
  [Event(name="io_error", type="flash.events.IOErrorEvent")]
  dynamic public class BootstrapProperties extends EventDispatcher
  {
    public function BootstrapProperties(propertiesFileName:String="flex.properties", propertiesUrl:String=null)
    {
       var url:String = propertiesFileName;
       if (propertiesUrl != null)
       {
         url = propertiesUrl + "/" + url;
       }
       var urlRequest:URLRequest = new URLRequest(url);
       var urlLoader:URLLoader = new URLLoader();
       
       urlLoader.addEventListener(Event.COMPLETE, propertiesLoadedHandler);
       urlLoader.addEventListener(IOErrorEvent.IO_ERROR, ioErrorHandler);
       
       urlLoader.load(urlRequest);
    }
    
    private function propertiesLoadedHandler(event:Event):void
    {
      var urlLoader:URLLoader = URLLoader(event.target);
      var propertiesText:String = urlLoader.data.toString();
      var properties:Array = propertiesText.split("\n");
      for each (var propertyText:String in properties)
      {
        var property:Array = propertyText.split("=");
        if (property.length == 2)
        {
          this[StringUtil.trim(property[0])] = StringUtil.trim(property[1]);
        }
        else
        {
          trace("Invalid property text: '" + propertyText + "'.");
        }
      }
      dispatchEvent(event);
    }
    
    private function ioErrorHandler(event:IOErrorEvent):void
    {
      dispatchEvent(event);
    }
  }
}