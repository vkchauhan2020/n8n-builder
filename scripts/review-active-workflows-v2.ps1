param(
    [switch]$WhatIf
)

$ErrorActionPreference = 'Stop'

function Load-EnvFile {
    param(
        [string]$Path
    )

    Get-Content $Path | ForEach-Object {
        if ($_ -match '^\s*([^#=]+)=(.*)$') {
            $name = $matches[1].Trim()
            $value = $matches[2].Trim()
            Set-Item -Path "Env:$name" -Value $value
        }
    }
}

function Get-ApiHeaders {
    return @{
        'X-N8N-API-KEY' = $env:N8N_API_KEY
        'Content-Type'  = 'application/json'
        'Accept'        = 'application/json'
    }
}

function Invoke-N8nApi {
    param(
        [Parameter(Mandatory = $true)][string]$Method,
        [Parameter(Mandatory = $true)][string]$Path,
        [object]$Body
    )

    $baseUrl = $env:N8N_API_URL.TrimEnd('/')
    $uri = "$baseUrl/api/v1/$Path"
    $headers = Get-ApiHeaders

    if ($null -ne $Body) {
        $json = $Body | ConvertTo-Json -Depth 100
        return Invoke-RestMethod -Uri $uri -Headers $headers -Method $Method -Body $json
    }

    return Invoke-RestMethod -Uri $uri -Headers $headers -Method $Method
}

function Simplify-Node {
    param(
        [Parameter(Mandatory = $true)][object]$Node
    )

    $copy = [ordered]@{
        id          = $Node.id
        name        = $Node.name
        type        = $Node.type
        typeVersion = $Node.typeVersion
        position    = @($Node.position[0], $Node.position[1])
        parameters  = $Node.parameters
    }

    if ($null -ne $Node.credentials) {
        $copy.credentials = $Node.credentials
    }

    if ($null -ne $Node.disabled) {
        $copy.disabled = [bool]$Node.disabled
    }

    if ($null -ne $Node.continueOnFail) {
        $copy.continueOnFail = [bool]$Node.continueOnFail
    }

    if ($null -ne $Node.retryOnFail) {
        $copy.retryOnFail = [bool]$Node.retryOnFail
    }

    if ($null -ne $Node.maxTries) {
        $copy.maxTries = $Node.maxTries
    }

    if ($null -ne $Node.waitBetweenTries) {
        $copy.waitBetweenTries = $Node.waitBetweenTries
    }

    if ($null -ne $Node.onError) {
        $copy.onError = $Node.onError
    }

    if ($null -ne $Node.notes) {
        $copy.notes = $Node.notes
    }

    if ($null -ne $Node.notesInFlow) {
        $copy.notesInFlow = [bool]$Node.notesInFlow
    }

    if ($null -ne $Node.webhookId) {
        $copy.webhookId = $Node.webhookId
    }

    return $copy
}

function Clone-JsonObject {
    param(
        [Parameter(Mandatory = $true)][object]$Value
    )

    $json = $Value | ConvertTo-Json -Depth 100
    return $json | ConvertFrom-Json -Depth 100
}

function Convert-ToOrderedMap {
    param(
        [object]$Value
    )

    $map = [ordered]@{}
    if ($null -eq $Value) {
        return $map
    }

    foreach ($prop in $Value.PSObject.Properties) {
        $map[$prop.Name] = $prop.Value
    }

    return $map
}

function Set-ObjectPropertyValue {
    param(
        [Parameter(Mandatory = $true)][object]$Object,
        [Parameter(Mandatory = $true)][string]$Name,
        [Parameter(Mandatory = $true)]$Value
    )

    if ($Object -is [System.Collections.IDictionary]) {
        $Object[$Name] = $Value
        return $Object
    }

    if ($Object.PSObject.Properties[$Name]) {
        $Object.$Name = $Value
    } else {
        Add-Member -InputObject $Object -NotePropertyName $Name -NotePropertyValue $Value -Force
    }

    return $Object
}

function Get-SupportedWorkflowSettings {
    param(
        [object]$Settings
    )

    $supportedKeys = @(
        'errorWorkflow',
        'executionOrder',
        'executionTimeout',
        'saveDataErrorExecution',
        'saveDataSuccessExecution',
        'saveExecutionProgress',
        'saveManualExecutions',
        'timezone'
    )

    $filtered = [ordered]@{}
    if ($null -eq $Settings) {
        return $filtered
    }

    foreach ($key in $supportedKeys) {
        if ($Settings -is [System.Collections.IDictionary]) {
            if ($Settings.Contains($key)) {
                $filtered[$key] = $Settings[$key]
            }
        } elseif ($Settings.PSObject.Properties[$key]) {
            $filtered[$key] = $Settings.$key
        }
    }

    return $filtered
}

function Update-TelegramNode {
    param(
        [Parameter(Mandatory = $true)][object]$Node
    )

    if (-not $Node.parameters.resource) {
        if ($Node.parameters.fileId) {
            Set-ObjectPropertyValue -Object $Node.parameters -Name 'resource' -Value 'file' | Out-Null
            Set-ObjectPropertyValue -Object $Node.parameters -Name 'operation' -Value 'get' | Out-Null
        } elseif ($Node.parameters.text) {
            Set-ObjectPropertyValue -Object $Node.parameters -Name 'resource' -Value 'message' | Out-Null
            Set-ObjectPropertyValue -Object $Node.parameters -Name 'operation' -Value 'sendMessage' | Out-Null
        }
    }

    return $Node
}

function Update-GoogleDriveNode {
    param(
        [Parameter(Mandatory = $true)][object]$Node
    )

    if (-not $Node.parameters.resource) {
        Set-ObjectPropertyValue -Object $Node.parameters -Name 'resource' -Value 'file' | Out-Null
    }

    if (-not $Node.parameters.operation) {
        Set-ObjectPropertyValue -Object $Node.parameters -Name 'operation' -Value 'upload' | Out-Null
    }

    return $Node
}

function Rename-NodeIfMatch {
    param(
        [Parameter(Mandatory = $true)][object]$Node,
        [Parameter(Mandatory = $true)][hashtable]$Map
    )

    if ($Map.ContainsKey($Node.name)) {
        $Node.name = $Map[$Node.name]
    }

    return $Node
}

function Update-Connections {
    param(
        [Parameter(Mandatory = $true)][object]$Connections,
        [Parameter(Mandatory = $true)][hashtable]$RenameMap
    )

    $old = $Connections.PSObject.Properties
    $newConnections = [ordered]@{}

    foreach ($prop in $old) {
        $sourceName = if ($RenameMap.ContainsKey($prop.Name)) { $RenameMap[$prop.Name] } else { $prop.Name }
        $payload = Clone-JsonObject -Value $prop.Value

        foreach ($channelProp in $payload.PSObject.Properties) {
            foreach ($branch in $channelProp.Value) {
                foreach ($conn in $branch) {
                    if ($RenameMap.ContainsKey($conn.node)) {
                        $conn.node = $RenameMap[$conn.node]
                    }
                }
            }
        }

        $newConnections[$sourceName] = $payload
    }

    return $newConnections
}

function Set-ChatIdOnNode {
    param(
        [Parameter(Mandatory = $true)][object]$Node,
        [Parameter(Mandatory = $true)][string]$ChatIdExpression
    )

    Set-ObjectPropertyValue -Object $Node.parameters -Name 'chatId' -Value $ChatIdExpression | Out-Null
    return $Node
}

function Set-ExecuteWorkflowReference {
    param(
        [Parameter(Mandatory = $true)][object]$Node,
        [Parameter(Mandatory = $true)][string]$WorkflowId,
        [Parameter(Mandatory = $true)][string]$WorkflowName
    )

    if ($Node.parameters.workflowId) {
        $Node.parameters.workflowId.value = $WorkflowId
        $Node.parameters.workflowId.cachedResultName = $WorkflowName
        $Node.parameters.workflowId.cachedResultUrl = "/workflow/$WorkflowId"
    }

    return $Node
}

function Set-ErrorWorkflowReference {
    param(
        [Parameter(Mandatory = $true)][object]$Workflow,
        [Parameter(Mandatory = $true)][string]$WorkflowId
    )

    if (-not $Workflow.settings) {
        $Workflow.settings = [ordered]@{}
    }

    $Workflow.settings.errorWorkflow = $WorkflowId
    return $Workflow
}

function Build-WorkflowDefinition {
    param(
        [Parameter(Mandatory = $true)][object]$Workflow
    )

    return [ordered]@{
        name        = $Workflow.name
        nodes       = $Workflow.nodes
        connections = $Workflow.connections
        settings    = $Workflow.settings
    }
}

$envPath = Join-Path (Get-Location) '.env.n8n-mcp'
Load-EnvFile -Path $envPath

$targetWorkflowIds = @(
    'ZUrih4bRXW4h6C0VItedW',
    'fHbCyDsmJYz24OyUB761-',
    'lE8v4qn0M0A2aQwA',
    'WSJiFKEqYYX3cjJJ',
    'IkcmoQk37Kw32Je8tWH9P',
    'B1wew4Pim8GiCAje',
    '1rh71C-Chs3-XfPM7eQn8',
    'NUZudtNaXEhDJTXvBzb3R',
    'cIPE4FGaEN7vzeaj',
    'tqxx9pSdjjxuPSvC6crfW'
)

$workflowConfigs = @{
    'ZUrih4bRXW4h6C0VItedW' = @{
        NewName   = 'Holiday Gatekeeper V2 (IST Safe)'
        RenameMap = @{
            "When clicking ‘Execute workflow’" = 'TRG_Manual_Test'
            'When Executed by Another Workflow' = 'TRG_Execute_From_Workflow'
            'Get row(s) in sheet' = 'SRC_Holiday_Sheet'
            'Code in JavaScript' = 'PROC_Evaluate_Trading_Day_IST'
        }
        Settings  = @{
            timezone = 'Asia/Kolkata'
        }
    }
    'fHbCyDsmJYz24OyUB761-' = @{
        NewName   = 'NSE Holiday List Sync V2'
        RenameMap = @{
            "When clicking ‘Execute workflow’" = 'TRG_Manual_Test'
            'Schedule Trigger' = 'TRG_Schedule_Mon_0800_IST'
            'Fatch Holiday List' = 'API_NSE_Fetch_Holiday_List'
            'Save Holiday List' = 'PROC_Normalize_Holiday_List'
            'Append or update Holiday List' = 'DB_Upsert_Holiday_List'
        }
        Settings  = @{
            timezone = 'Asia/Kolkata'
        }
    }
    'lE8v4qn0M0A2aQwA' = @{
        NewName   = 'Global Error Handler V2 (Telegram + Sheets)'
        RenameMap = @{
            'Error Trigger' = 'TRG_Error'
            'Send Telegram Alert' = 'OUT_Telegram_Error_Alert'
            'Log Error' = 'DB_Log_Error_To_Sheets'
        }
    }
    'WSJiFKEqYYX3cjJJ' = @{
        NewName   = 'NIFTY Intraday Option Buying V2'
        RenameMap = @{
            'If' = 'IF_Trading_Day'
            'If1' = 'IF_Valid_Telegram_Command'
            'Telegram Trigger' = 'TRG_Telegram_Command'
            'OUT_Telegram_Send_Alert1' = 'OUT_Telegram_Send_Halt_Alert'
            'TRG_Schedule' = 'TRG_Schedule_Intraday'
        }
    }
    'IkcmoQk37Kw32Je8tWH9P' = @{
        NewName   = 'NIFTY Intraday Option Selling V2'
        RenameMap = @{
            "When clicking ‘Execute workflow’" = 'TRG_Manual_Start'
            'AI Agent' = 'AI_Generate_Option_Selling_Plan'
            'Google Gemini Chat Model1' = 'AI_Model_Gemini'
            'Simple Memory' = 'AI_Session_Memory'
            'NIFTY 50 fatch' = 'API_NSE_Fetch_IndexData'
            'Code in JavaScript' = 'PROC_Build_Market_Context'
            'NIFTY 50 Fatch Expiry Date' = 'API_NSE_Fetch_ExpiryDates'
            'Merge' = 'UTIL_Merge_Market_Expiry'
            'Code in JavaScript1' = 'PROC_Format_Telegram_Message'
            'Schedule Trigger' = 'TRG_Schedule_0920_IST'
            'Send a text message to AlgoSignals — Intraday' = 'OUT_Telegram_Send_Alert'
            'If' = 'IF_Trading_Day'
            'Send a text message to AlgoSignals — Intraday1' = 'OUT_Telegram_Send_Halt_Alert'
        }
    }
    'B1wew4Pim8GiCAje' = @{
        NewName   = 'NIFTY 9:30 AM Intraday Option-Buying Agent V2'
        RenameMap = @{
            'TRG_Schedule_0935_IST' = 'TRG_Schedule_0930_IST'
        }
        Settings  = @{
            timezone = 'Asia/Kolkata'
        }
        SchedulePatch = @{
            NodeName = 'TRG_Schedule_0935_IST'
            Expression = '30 9 * * 1-5'
        }
        ChatOverrides = @{
            'OUT_Telegram_Send_Alert' = '=-1003739030993'
            'OUT_Telegram_Send_Halt_Alert' = '=-1003739030993'
        }
    }
    '1rh71C-Chs3-XfPM7eQn8' = @{
        NewName   = 'Telegram Image to Drive PDF Saver V2'
        RenameMap = @{
            'Telegram Trigger1' = 'TRG_Telegram_Message'
            'Has Photo?1' = 'IF_Has_Image_Payload'
            'Get File Info1' = 'API_Telegram_Get_File'
            'Set Variables1' = 'PROC_Prepare_Download_Context'
            'Download Image1' = 'API_Telegram_Download_File'
            'Convert to PDF' = 'PROC_Convert_Image_To_PDF'
            'Upload to Google Drive1' = 'DRIVE_Upload_PDF'
            'Send Confirmation1' = 'OUT_Telegram_Send_Confirmation'
        }
    }
    'NUZudtNaXEhDJTXvBzb3R' = @{
        NewName   = 'Gold Multi-Timeframe Session Analysis V2'
    }
    'cIPE4FGaEN7vzeaj' = @{
        NewName   = 'NIFTY Non-Directional Option Buying Strategy V2'
        RenameMap = @{
            "When clicking ‘Execute workflow’" = 'TRG_Manual_Start'
            'AI Agent' = 'AI_Generate_NonDirectional_Plan'
            'Google Gemini Chat Model1' = 'AI_Model_Gemini'
            'Simple Memory' = 'AI_Session_Memory'
            'NIFTY 50 fatch' = 'API_NSE_Fetch_IndexData'
            'NIFTY 50 Fatch Expiry Date' = 'API_NSE_Fetch_ExpiryDates'
            'Merge' = 'UTIL_Merge_Market_Expiry'
            'Schedule Trigger' = 'TRG_Schedule'
            'Data filter for Prompt' = 'PROC_Build_Prompt_Context'
            'Send a text message' = 'OUT_Telegram_Send_Alert'
        }
    }
    'tqxx9pSdjjxuPSvC6crfW' = @{
        NewName   = 'Windows EC2 Start and Stop Orchestrator V2'
        RenameMap = @{
            'Schedule Trigger1' = 'TRG_Schedule_Stop_1532_IST'
            'If1' = 'IF_Trading_Day'
            'Manual Trigger' = 'TRG_Manual_Start'
            'OUT_Telegram_Send_Alert2' = 'OUT_Telegram_Send_Startup_Alert'
            'Code in JavaScript' = 'PROC_Parse_Instance_State'
            'XML' = 'PROC_Parse_DescribeInstances_XML'
        }
    }
}

$createdWorkflows = @{}
$fullWorkflowData = @{}

foreach ($workflowId in $targetWorkflowIds) {
    $fullWorkflowData[$workflowId] = Invoke-N8nApi -Method GET -Path "workflows/$workflowId"
}

foreach ($workflowId in @('ZUrih4bRXW4h6C0VItedW', 'fHbCyDsmJYz24OyUB761-', 'lE8v4qn0M0A2aQwA')) {
    $rawWorkflow = $fullWorkflowData[$workflowId]
    $config = $workflowConfigs[$workflowId]

    $nodes = @()
    foreach ($node in $rawWorkflow.nodes) {
        $nodeCopy = Simplify-Node -Node $node
        $nodeCopy = Rename-NodeIfMatch -Node $nodeCopy -Map $config.RenameMap
        if ($nodeCopy.type -eq 'n8n-nodes-base.telegram') {
            $nodeCopy = Update-TelegramNode -Node $nodeCopy
        }
        if ($nodeCopy.type -eq 'n8n-nodes-base.googleDrive') {
            $nodeCopy = Update-GoogleDriveNode -Node $nodeCopy
        }
        $nodes += $nodeCopy
    }

    $connections = Update-Connections -Connections $rawWorkflow.connections -RenameMap $config.RenameMap
    $settings = Get-SupportedWorkflowSettings -Settings $rawWorkflow.settings
    foreach ($settingName in $config.Settings.Keys) {
        $settings[$settingName] = $config.Settings[$settingName]
    }

    $newWorkflow = [ordered]@{
        name        = $config.NewName
        nodes       = $nodes
        connections = $connections
        settings    = $settings
    }

    if ($WhatIf) {
        Write-Output "WHATIF create: $($config.NewName)"
        continue
    }

    $created = Invoke-N8nApi -Method POST -Path 'workflows' -Body $newWorkflow
    $createdWorkflows[$workflowId] = $created.id
}

$holidayGatekeeperV2Id = if ($WhatIf) { 'WHATIF-HOLIDAY-GATEKEEPER-V2' } else { $createdWorkflows['ZUrih4bRXW4h6C0VItedW'] }
$holidayGatekeeperV2Name = $workflowConfigs['ZUrih4bRXW4h6C0VItedW'].NewName
$errorHandlerV2Id = if ($WhatIf) { 'WHATIF-ERROR-HANDLER-V2' } else { $createdWorkflows['lE8v4qn0M0A2aQwA'] }

foreach ($workflowId in @('WSJiFKEqYYX3cjJJ', 'IkcmoQk37Kw32Je8tWH9P', 'B1wew4Pim8GiCAje', '1rh71C-Chs3-XfPM7eQn8', 'NUZudtNaXEhDJTXvBzb3R', 'cIPE4FGaEN7vzeaj', 'tqxx9pSdjjxuPSvC6crfW')) {
    $rawWorkflow = $fullWorkflowData[$workflowId]
    $config = $workflowConfigs[$workflowId]
    $renameMap = if ($config.RenameMap) { $config.RenameMap } else { @{} }

    $nodes = @()
    foreach ($node in $rawWorkflow.nodes) {
        $nodeCopy = Simplify-Node -Node $node
        $nodeCopy = Rename-NodeIfMatch -Node $nodeCopy -Map $renameMap

        if ($nodeCopy.type -eq 'n8n-nodes-base.executeWorkflow') {
            $nodeCopy = Set-ExecuteWorkflowReference -Node $nodeCopy -WorkflowId $holidayGatekeeperV2Id -WorkflowName $holidayGatekeeperV2Name
        }

        if ($nodeCopy.type -eq 'n8n-nodes-base.telegram') {
            $nodeCopy = Update-TelegramNode -Node $nodeCopy
            if ($config.ChatOverrides -and $config.ChatOverrides.ContainsKey($nodeCopy.name)) {
                $nodeCopy = Set-ChatIdOnNode -Node $nodeCopy -ChatIdExpression $config.ChatOverrides[$nodeCopy.name]
            }
        }

        if ($nodeCopy.type -eq 'n8n-nodes-base.googleDrive') {
            $nodeCopy = Update-GoogleDriveNode -Node $nodeCopy
        }

        if ($config.SchedulePatch -and $node.name -eq $config.SchedulePatch.NodeName) {
            $nodeCopy.parameters.rule.interval[0].expression = $config.SchedulePatch.Expression
        }

        if ($workflowId -eq '1rh71C-Chs3-XfPM7eQn8' -and $nodeCopy.name -eq 'IF_Has_Image_Payload') {
            $nodeCopy.parameters.conditions.conditions[0].leftValue = '={{ (Array.isArray($json.message.photo) && $json.message.photo.length > 0) || ($json.message.document?.mime_type && $json.message.document.mime_type.startsWith("image/")) }}'
        }

        if ($workflowId -eq '1rh71C-Chs3-XfPM7eQn8' -and $nodeCopy.name -eq 'API_Telegram_Get_File') {
            $nodeCopy.parameters.fileId = '={{ Array.isArray($json.message.photo) && $json.message.photo.length > 0 ? $json.message.photo[$json.message.photo.length - 1].file_id : $json.message.document.file_id }}'
        }

        $nodes += $nodeCopy
    }

    $connections = Update-Connections -Connections $rawWorkflow.connections -RenameMap $renameMap
    $settings = Get-SupportedWorkflowSettings -Settings $rawWorkflow.settings
    if ($errorHandlerV2Id) {
        $settings.errorWorkflow = $errorHandlerV2Id
    }
    if ($config.Settings) {
        foreach ($settingName in $config.Settings.Keys) {
            $settings[$settingName] = $config.Settings[$settingName]
        }
    }

    $newWorkflow = [ordered]@{
        name        = $config.NewName
        nodes       = $nodes
        connections = $connections
        settings    = $settings
    }

    if ($WhatIf) {
        Write-Output "WHATIF create: $($config.NewName)"
        continue
    }

    $created = Invoke-N8nApi -Method POST -Path 'workflows' -Body $newWorkflow
    $createdWorkflows[$workflowId] = $created.id
}

if (-not $WhatIf) {
    $summary = foreach ($workflowId in $targetWorkflowIds) {
        [pscustomobject]@{
            SourceWorkflowId = $workflowId
            SourceName       = $fullWorkflowData[$workflowId].name
            V2WorkflowId     = $createdWorkflows[$workflowId]
            V2Name           = $workflowConfigs[$workflowId].NewName
        }
    }

    $summary | ConvertTo-Json -Depth 5
}
