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
  import mx.controls.Alert;
  import mx.core.Application;
  import mx.messaging.ChannelSet;
  import mx.messaging.channels.AMFChannel;
  import mx.messaging.channels.SecureAMFChannel;
  import mx.rpc.remoting.RemoteObject;
  
  public class RemoteObjectRepository
  {
    static public const RELATIVE_CONTEXT_ROOT:String = "RelativeContextRoot";
    static public const RELATIVE_CHANNEL_URL:String = "RelativeChannelUrl";
    static public const CHANNEL_URL:String = "ChannelUrl";
    static public const CHANNEL_NAME:String = "ChannelName";
    static public const USE_SECURE_CHANNEL_ENDPOINT:String = "SecureChannelEndpoint";
    
    public var defaultRelativeChannelUrl:String = "/messagebroker/amf";
    public var defaultSecureRelativeChannelUrl:String = "/messagebroker/amfsecure";
    public var defaultUseSecurityEndpointIfSsl:Boolean = true;
    public var defaultChannelName:String = "my-amf";
    public var defaultSecureChannelName:String = "secure-amf";

    private var properties:BootstrapProperties;
    private var _usingSsl = false;
    private var _channelName:String
    private var _channelEndpointUrl:String;
    private var _useSecureChannelEndpoint:Boolean;

    public function RemoteObjectRepository(properties:BootstrapProperties=null)
    {
      this.properties = properties;
    } 
    
    public function initialize(swfUrl:String):void
    {
      _channelEndpointUrl = getProperty(CHANNEL_URL);
      if (_channelEndpointUrl == null)
      {
        var lastSlash:int = swfUrl.lastIndexOf("/");
        if (lastSlash > 0)
        {
          var baseUrl:String = swfUrl.substring(0, lastSlash); 
          _usingSsl = baseUrl.substring(0, 5).toLocaleLowerCase() == "https";

          var relativeContextRoot:String = getProperty(RELATIVE_CONTEXT_ROOT);
          if (relativeContextRoot != null)
          {
            baseUrl += relativeContextRoot;
          }
          
          var relativeChannelUrl:String = getProperty(RELATIVE_CHANNEL_URL);
          if (relativeChannelUrl == null) relativeChannelUrl = _usingSsl ? defaultSecureRelativeChannelUrl : defaultRelativeChannelUrl;
          
          _channelEndpointUrl = baseUrl + relativeChannelUrl;
        }
      }
      else
      {
        _usingSsl = _channelEndpointUrl.substring(0, 5).toLocaleLowerCase() == "https";
      }
      
      if (_usingSsl)
      {
        _useSecureChannelEndpoint = defaultUseSecurityEndpointIfSsl;
      }
      else
      {
        _useSecureChannelEndpoint = false;
      }
      
      _channelName = getProperty(CHANNEL_NAME);
      if (_channelName == null) _channelName = _usingSsl ? defaultSecureChannelName : defaultChannelName;
    }
    
    public function createRemoteObject(destination:String):RemoteObject
    {
      var remoteObject:RemoteObject = new RemoteObject();
      remoteObject.destination = destination;
      
      var channelSet:ChannelSet = new ChannelSet();
      
      var amfChannel:AMFChannel;
      if (_useSecureChannelEndpoint)
      {
        amfChannel = new SecureAMFChannel(_channelName, _channelEndpointUrl);
      }
      else
      {
        amfChannel = new AMFChannel(_channelName, _channelEndpointUrl);
      }
      
      channelSet.addChannel(amfChannel);
      remoteObject.channelSet = channelSet;
      
      return remoteObject;
    }
    
    public function get usingSsl():Boolean
    {
      return _usingSsl;
    }
    
    private function get channelEndpointUrl():String
    {
      return _channelEndpointUrl;
    }
    
    private function get channelName():String
    {
      return _channelName;
    }
    
    private function get secureChannelEndpoint():Boolean
    {
      return _useSecureChannelEndpoint;
    }
    
    private function getProperty(propertyName:String):String
    {
      if (properties == null)
      {
        return null;
      }
      else if (properties[propertyName] == undefined)
      {
        return null;
      }
      else
      {
        return properties[propertyName];        
      }
    }
  }
}
