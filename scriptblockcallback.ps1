#requires -version 2.0

# Found at https://web.archive.org/web/20160404214529/http://poshcode.org/1382

function New-ScriptBlockCallback {
    param(
        [parameter(Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [scriptblock]$Callback
    )
    <#
    .SYNOPSIS
        Allows running ScriptBlocks via .NET async callbacks.
 
    .DESCRIPTION
        Allows running ScriptBlocks via .NET async callbacks. Internally this is
        managed by converting .NET async callbacks into .NET events. This enables
        PowerShell 2.0 to run ScriptBlocks indirectly through Register-ObjectEvent.        
 
    .PARAMETER Callback
        Specify a ScriptBlock to be executed in response to the callback.
        Because the ScriptBlock is executed by the eventing subsystem, it only has
        access to global scope. Any additional arguments to this function will be
        passed as event MessageData.
       
    .EXAMPLE
        You wish to run a scriptblock in reponse to a callback. Here is the .NET
        method signature:
       
        void Bar(AsyncCallback handler, int blah)
       
        ps> [foo]::bar((New-ScriptBlockCallback { ... }), 42)                        
 
    .OUTPUTS
        A System.AsyncCallback delegate.
#>
    # is this type already defined?    
    if (-not ("CallbackEventBridge" -as [type])) {
        Add-Type @"
           using System;
           
           public sealed class CallbackEventBridge
           {
               public event AsyncCallback CallbackComplete = delegate { };
 
               private CallbackEventBridge() {}
 
               private void CallbackInternal(IAsyncResult result)
               {
                   CallbackComplete(result);
               }
 
               public AsyncCallback Callback
               {
                   get { return new AsyncCallback(CallbackInternal); }
               }
 
               public static CallbackEventBridge Create()
               {
                   return new CallbackEventBridge();
               }
           }
"@
    }
    $bridge = [callbackeventbridge]::create()
    Register-ObjectEvent -input $bridge -EventName callbackcomplete -action $callback -messagedata $args > $null
    $bridge.callback
}