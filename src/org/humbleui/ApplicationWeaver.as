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
  import flash.events.IEventDispatcher;
  import flash.utils.Dictionary;
  import flash.utils.describeType;
  import flash.utils.getDefinitionByName;
  import flash.utils.getQualifiedClassName;
  
  import mx.collections.ArrayCollection;
  import mx.core.Application;
  import mx.core.Container;
  import mx.core.IVisualElement;
  import mx.core.IVisualElementContainer;
  import mx.core.UIComponent;
  import mx.events.ChildExistenceChangedEvent;
  import mx.events.FlexEvent;
  import mx.managers.SystemManager;
  
  import spark.components.SkinnableContainer;
  import spark.components.supportClasses.SkinnableComponent;
  import spark.events.ElementExistenceEvent;
  
  /**
    * Responsible for wiring all views to matching mediators within the application. This class needs to be initialized
    * at startup. 
    *
    * This is where all the beautiful magic happens.
    *  
    */
  public class ApplicationWeaver
  {
    private var containerApp:UIComponent;
    private var mediatorDefsMap:Object = new Object();
    private var uiDefsMap:Object = new Object();
    private var visitedUIWeakMap:Dictionary = new Dictionary(true);
    private var mediatorsMap:Object = new Object();
    private var stateObjectMap:Object = new Object();
    private var dynamicRepoTypeName:String = getQualifiedClassName(RemoteObjectRepository);
    private var propertiesTypeName:String = getQualifiedClassName(BootstrapProperties); 
    
    private var dynamicRemoteObjectRepo:RemoteObjectRepository;
    private var properties:BootstrapProperties;
    
    public function ApplicationWeaver(mediatorClasses:Array, containerApp:UIComponent, 
        dynamicRemoteObjectRepo:RemoteObjectRepository=null, properties:BootstrapProperties=null)
    {
      this.containerApp = containerApp;
      this.properties = properties;
      
      if (dynamicRemoteObjectRepo == null)
      {
        this.dynamicRemoteObjectRepo = new RemoteObjectRepository();
        this.dynamicRemoteObjectRepo.initialize(Object(containerApp).url);
      }
      else
      {
        this.dynamicRemoteObjectRepo = dynamicRemoteObjectRepo;
      }

      
      for each (var mediatorClass:Class in mediatorClasses)
      {
        mediatorDefsMap[getQualifiedClassName(mediatorClass)] = createMediatorDefinition(mediatorClass);
      }
      
      containerApp.systemManager.addEventListener(Event.ADDED, windowAddedEventHandler, false, 0, true);
      weave(containerApp);
    }
    
    
    private function windowAddedEventHandler(event:Event):void
    {
      var child:Container = event.target as Container;
      if (child)
      {
        weave(child);
      }
    }
    
    private function containerAddedEventHandler(event:ChildExistenceChangedEvent):void
    {
      var uiComponent:UIComponent = event.relatedObject as UIComponent;
      if (uiComponent)
      {
        weave(uiComponent);
      }
    }

    private function elementAddedEventHandler(event:ElementExistenceEvent):void
    {
      var uiComponent:UIComponent = event.element as UIComponent;
      if (uiComponent)
      {
        weave(uiComponent);
      }
    }

    private function weave(uiComponent:UIComponent):void
    {
      
      if (visitedUIWeakMap[uiComponent.uid] == undefined)
      {
        visitedUIWeakMap[uiComponent.uid] = true;

        var qualifiedClassName:String = getQualifiedClassName(uiComponent);
        if ((uiDefsMap[qualifiedClassName] != undefined))
        {
          var uiDef:UIDefinition = uiDefsMap[qualifiedClassName];
          
          for each (var stateObject:* in uiDef.stateObjectNames)
          {
            uiComponent[stateObject.name] = getStateObject(stateObject.type);
          }
          
          for each (var mediatorDefinition:MediatorDefinition in uiDef.wiredMediatorDefs)
          {
            var mediatorClass:Class = mediatorDefinition.mediatorClass;
            var mediatorTypeName:String = getQualifiedClassName(mediatorClass);
            var mediator:* = new mediatorClass(uiComponent);
            
            /*
             * If any exisiting mediators are wired to this new mediator set that
             * reference now.
             */ 
            for each (var existingMediatorTuple:WeakReference in mediatorsMap)
            {
              if (existingMediatorTuple.getObject() != null)
              {
                var existingMediator:* = existingMediatorTuple.getObject();
                var existingDef:MediatorDefinition = mediatorDefsMap[getQualifiedClassName(existingMediator)];
  
                for each (var mediatorFriend in existingDef.mediatorFriends)
                {
                  if (mediatorFriend.type == mediatorTypeName)
                  {
                    existingMediator[mediatorFriend.name.toString()] = mediator;
                  }
                }            
              }
            }
            
            mediatorsMap[mediatorTypeName] = new WeakReference(mediator);
            var mediatorXml:XML = describeType(mediator);
            
            var variableList:XMLList = mediatorXml.variable;
            for each (var variable:XML in variableList)
            {
              if ((dynamicRemoteObjectRepo != null) && (variable.@type.toString() == dynamicRepoTypeName))
              {
                mediator[variable.@name.toString()] = dynamicRemoteObjectRepo;
              }
    
              if ((properties != null) && (variable.@type.toString() == propertiesTypeName))
              {
                mediator[variable.@name.toString()] = properties;
              }
            }
            
            for each (var remoteObjectProxyMeta:Object in mediatorDefinition.remoteObjectProxyMetas)
            {
              var defaultFaultHandler:Function = (mediatorDefinition.defaultFaultHandlerName == null) 
                  ? null : mediator[mediatorDefinition.defaultFaultHandlerName];

              var defaultResultHandler:Function = (mediatorDefinition.defaultResultHandlerName == null) 
                  ? null : mediator[mediatorDefinition.defaultResultHandlerName];
              
              var remoteObjectProxy:RemoteObjectProxy = new RemoteObjectProxy(remoteObjectProxyMeta.destination, dynamicRemoteObjectRepo,
                  defaultFaultHandler, defaultResultHandler);
              
              mediator[remoteObjectProxyMeta.name] = remoteObjectProxy;
            }
            
            for each (var stateObject:* in mediatorDefinition.stateObjectNames)
            {
              mediator[stateObject.name] = getStateObject(stateObject.type);
            }
            
            for each (var rootDispatcherName:String in mediatorDefinition.rootDispatcherNames)
            {
              mediator[rootDispatcherName] = SystemManager.getSWFRoot(containerApp);
            }

            for each (var mediatorFriend in mediatorDefinition.mediatorFriends)
            {
              var typeString:String = mediatorFriend.type.toString(); 
              if (mediatorsMap[typeString] != undefined)
              {
                var weakRef:WeakReference = mediatorsMap[typeString];
                mediator[mediatorFriend.name.toString()] = weakRef.getObject();
              }
            }
            
            if (mediatorDefinition.implementsMediatorLifecycyle)
            {
              mediator.mediatorCreationComplete();
            }
          }
        }
        
        if (uiComponent is Container)
        {
          uiComponent.addEventListener(ChildExistenceChangedEvent.CHILD_ADD, containerAddedEventHandler, false, 0, true);
          for each (var child:Object in Container(uiComponent).getChildren())
          {
            if (child is UIComponent)
            { 
              weave(UIComponent(child)); 
            }
          } 
        }
        else if (uiComponent is SkinnableContainer)
        {
          SkinnableComponent(uiComponent).addEventListener(ElementExistenceEvent.ELEMENT_ADD, elementAddedEventHandler);
          for (var i:int = 0; i < SkinnableContainer(uiComponent).numElements; i++)
          {
            var visualElement:IVisualElement = SkinnableContainer(uiComponent).getElementAt(i);
            if (visualElement is UIComponent)
            {
              weave(UIComponent(visualElement));
            }
          }
        }
      }
    }
    
    private function createMediatorDefinition(mediatorClass:Class):MediatorDefinition
    {
      var mediatorDef:MediatorDefinition = new MediatorDefinition();
      mediatorDef.mediatorClass = mediatorClass;
      
      try
      {
        /*
         * Workaround for bug http://bugs.adobe.com/jira/browse/FP-183 
         * Assuming the mediator has a single constructor with the ui as a paramter. 
         * If this changes then will need to get a little smarter about the number
         * of arguments to pass in here.
         */
        new mediatorClass(new Object());
      }
      catch (e:Error)
      {} // Should get type conversion error here
      
      var mediatorClassDesc:XML = describeType(mediatorClass);
      var typeName:String = mediatorClassDesc.@name.toString();
      
      var factoryXml:XML = mediatorClassDesc.factory[0]; // TODO Is this is always right? I don't really understand this.
      var constructorXmlList:XMLList = factoryXml.constructor;
      var containerClassName:String = getQualifiedClassName(Container);
      
      /*
       * Find the constructor that has one parameter and whose argument is a
       * descendant of UIComponent.
       */
      for each (var constructorXml:XML in constructorXmlList)
      {
        var parameterXmlList:XMLList = constructorXml.parameter;
        if (parameterXmlList.length() == 1)
        {
          var typeName:String = parameterXmlList[0].@type;
          
          try
          {
            var uiCandidateClass:Class = Class(getDefinitionByName(typeName));
            var uiCandidate:* = new uiCandidateClass();
            if (uiCandidate instanceof UIComponent)
            {
              mediatorDef.wiredUIDefinition = createUIDefinition(uiCandidateClass, mediatorDef);
              break;
            }
          }
          catch (e:Error)
          {
            trace(e);
          }
        }
      }
      
      if (mediatorDef.wiredUIDefinition == null)
      {
        throw new Error("Mediator type " + typeName + " does not have a constructor with a single UIComponent descendant constructor.");
      }
      
      mediatorDef.implementsMediatorLifecycyle = (factoryXml.implementsInterface.(@type == "org.humbleui::IMediatorLifecycle").length() > 0);
      
      var variableXmlList:XMLList = factoryXml.variable;
      var eventDispatcherName:String = getQualifiedClassName(IEventDispatcher);
      
      
      // Weave remote objects
      var remoteObjectVariablesList:XMLList = factoryXml.variable.(elements('metadata').@name == "RemoteObject");
      for each (var remoteObjectVariable:XML in remoteObjectVariablesList)
      {
        var variableName:String = remoteObjectVariable.@name;            

        if ((remoteObjectVariable.@type == "*") || (remoteObjectVariable.@type == "org.humbleui::RemoteObjectProxy"))
        {
          var remoteObjectMetaXml:XML = remoteObjectVariable.metadata.(@name == "RemoteObject")[0];
          var destinationArgXmlList:XMLList = remoteObjectMetaXml.arg.(@key == "destination");
          
          if (destinationArgXmlList.length() != 1)
          {
            throw new Error("Mediator type " + typeName + " has invalid RemoteObject variable " + variableName + " with no destination specified.");
          }
          
          var destinationArgXml:XML = destinationArgXmlList[0];
          var destination:String = destinationArgXml.@value;
          mediatorDef.remoteObjectProxyMetas.addItem({name: variableName, destination: destination});
        }
        else
        {
          throw new Error("Mediator type " + typeName + " has invalid RemoteObject variable " 
          + variableName + " must be of type * not " + remoteObjectVariable.@type);
        }
      }

      // Weave mediator objects
      var mediatorVariablesList:XMLList = factoryXml.variable;
      for each (var mediatorVariable:XML in mediatorVariablesList)
      {
        var hasMediatorMetadata:Boolean = false;
        var metadataList:XMLList = mediatorVariable.metadata;
        for each (var metadata:XML in metadataList)
        {
          if (metadata.@name == "Mediator")
          {
            hasMediatorMetadata = true;
            break;
          }
        }
        
        if (hasMediatorMetadata)
        {
          mediatorDef.mediatorFriends.addItem({name: mediatorVariable.@name, type: mediatorVariable.@type});
        }
      }
      
      // Weave state objects
      var stateObjectVariablesList:XMLList = factoryXml.variable;
      for each (var stateObjectVariable:XML in stateObjectVariablesList)
      {
        var hasStateObjectMetadata:Boolean = false;
        var metadataList:XMLList = stateObjectVariable.metadata;
        for each (var metadata:XML in metadataList)
        {
          if (metadata.@name == "StateObject")
          {
            hasStateObjectMetadata = true;
            break;
          }
        }
        
        if (hasStateObjectMetadata)
        {
          mediatorDef.stateObjectNames.addItem({name: stateObjectVariable.@name, type: stateObjectVariable.@type});
        }
      }

      
      // Weave root dispatch objects
      var rootDispatchObjectVariables:XMLList = factoryXml.variable;
      for each (var rootDispatchVariable:XML in rootDispatchObjectVariables)
      {
        var hasRootDispatcherMetadata:Boolean = false;
        var metadataList:XMLList = rootDispatchVariable.metadata;
        for each (var metadata:XML in metadataList)
        {
          if (metadata.@name == "RootDispatcher")
          {
            hasRootDispatcherMetadata = true;
            break;
          }
        }

        if (hasRootDispatcherMetadata)
        {
          if (rootDispatchVariable.@type == "flash.events::IEventDispatcher")
          {
            mediatorDef.rootDispatcherNames.addItem(rootDispatchVariable.@name);
          }
          else
          {
            throw new Error("Mediator type " + typeName + " has invalid RootDispatcher variable " + rootDispatchVariable.@name + " must be of type flash.events::IEventDispatcher");
          }
        }
      }

      
      var defaultFaultHandlers:XMLList = factoryXml.method.(elements('metadata').@name == "DefaultFaultHandler");
      if (defaultFaultHandlers.length() > 0)
      {
        mediatorDef.defaultFaultHandlerName = defaultFaultHandlers[0].@name;
      }

      var defaultResultHandlers:XMLList = factoryXml.method.(elements('metadata').@name == "DefaultResultHandler");
      if (defaultResultHandlers.length() > 0)
      {
        mediatorDef.defaultResultHandlerName = defaultResultHandlers[0].@name;
      }

      return mediatorDef;
    }
    
    private function createUIDefinition(uiClass:Class, mediatorDef:MediatorDefinition):UIDefinition
    {
      var uiDef:UIDefinition;
      var className:String = getQualifiedClassName(uiClass);
      if (uiDefsMap[className] != undefined)
      {
        uiDef = uiDefsMap[className];
      }
      else
      {
        uiDef = new UIDefinition();
        uiDef.uiClass = uiClass;
        uiDef.qualifiedClassName = className;
        
        var uiDescXml:XML = describeType(uiClass);
        var factoryXml:XML = uiDescXml.factory[0]; // TODO Is this is always right? I don't really understand this.
        
        var stateObjectXmlLists:ArrayCollection = new ArrayCollection();
        stateObjectXmlLists.addItem(factoryXml.elements('accessor').elements('metadata').(@name == "StateObject"));
        stateObjectXmlLists.addItem(factoryXml.elements('variable').elements('metadata').(@name == "StateObject"));
        
        for each (var stateObjectMetaList:XMLList in stateObjectXmlLists)
        {
          for each (var stateObjectMeta:XML in stateObjectMetaList)
          {
            var accessor:XML = stateObjectMeta.parent();
            uiDef.stateObjectNames.addItem({name: accessor.@name, type: accessor.@type});
          }
        }
        
        uiDefsMap[className] = uiDef;
      }
      
      uiDef.wiredMediatorDefs.addItem(mediatorDef);
      return uiDef;
    }
    
    private function getStateObject(typeName:String):Object
    {
      if (stateObjectMap[typeName] != undefined)
      {
        return stateObjectMap[typeName];
      }
      else
      {
        var stateObjectClass:Class = Class(getDefinitionByName(typeName));
        var stateObject:Object = new stateObjectClass();
        stateObjectMap[typeName] = stateObject;
        return stateObject;
      }
    }
  }
}
  
import mx.collections.ArrayCollection;
import flash.utils.getQualifiedClassName;

internal class MediatorDefinition
{
  public var mediatorClass:Class;
  public var wiredUIDefinition:UIDefinition;
  public var implementsMediatorLifecycyle:Boolean;
  public var remoteObjectProxyMetas:ArrayCollection = new ArrayCollection();
  public var stateObjectNames:ArrayCollection = new ArrayCollection();
  public var rootDispatcherNames:ArrayCollection = new ArrayCollection();
  public var mediatorFriends:ArrayCollection = new ArrayCollection();
  public var defaultFaultHandlerName:String;
  public var defaultResultHandlerName:String;
  
  public function toString():String
  {
    return mediatorClass.toString() + " => " + wiredUIDefinition;
  }
}

internal class UIDefinition
{
  public var uiClass:Class;
  public var qualifiedClassName:String;
  public var stateObjectNames:ArrayCollection = new ArrayCollection();
  public var wiredMediatorDefs:ArrayCollection = new ArrayCollection();
  
  public function toString():String
  {
    return getQualifiedClassName(uiClass);
  }
}
