@description('Name of the environment. Used to generate unique resource names.')
param environmentName string

@description('Azure region for all resources')
param location string = resourceGroup().location

@description('Array of IP addresses or CIDR blocks allowed to access the AIL Framework. Leave empty to allow all IPs.')
param allowedIPRanges array = ['84.196.68.19']

@description('Enable IP allowlist restriction for AIL Framework')
param enableIPRestriction bool = true

@description('Container image for AIL service')
param ailImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

@description('Container image for Lacus service')
param lacusImage string = 'mcr.microsoft.com/azuredocs/containerapps-helloworld:latest'

// Generate unique resource token based on subscription ID, resource group ID, and environment name
var resourceToken = uniqueString(subscription().id, resourceGroup().id, environmentName)

// Create IP security restrictions array
var ipSecurityRestrictions = [for ipRange in allowedIPRanges: {
  ipAddressRange: ipRange
  action: 'Allow'
  name: 'Allow-${replace(ipRange, '/', '-')}'
}]

// Resource naming following Azure best practices: {prefix}-{resourceToken}
var resourceNames = {
  containerAppsEnvironment: toLower('cae-${resourceToken}')
  containerRegistry: toLower('acr${resourceToken}')
  redisCache: toLower('redis-${resourceToken}')
  storageAccount: toLower('st${resourceToken}')
  keyVault: toLower('kv-${resourceToken}')
  logAnalytics: toLower('la-${resourceToken}')
  applicationInsights: toLower('ai-${resourceToken}')
  managedIdentity: toLower('id-${resourceToken}')
  ailApp: 'ail'
  lacusApp: 'lacus'
}

// Create Log Analytics Workspace for monitoring
resource logAnalytics 'Microsoft.OperationalInsights/workspaces@2023-09-01' = {
  name: resourceNames.logAnalytics
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    sku: {
      name: 'PerGB2018'
    }
    retentionInDays: 30
  }
}

// Create Application Insights for telemetry
resource applicationInsights 'Microsoft.Insights/components@2020-02-02' = {
  name: resourceNames.applicationInsights
  location: location
  kind: 'web'
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    Application_Type: 'web'
    WorkspaceResourceId: logAnalytics.id
    IngestionMode: 'LogAnalytics'
  }
}

// Create User-Assigned Managed Identity for secure access
resource managedIdentity 'Microsoft.ManagedIdentity/userAssignedIdentities@2023-01-31' = {
  name: resourceNames.managedIdentity
  location: location
  tags: {
    'azd-env-name': environmentName
  }
}

// Create Azure Container Registry for storing container images
resource containerRegistry 'Microsoft.ContainerRegistry/registries@2023-07-01' = {
  name: resourceNames.containerRegistry
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  sku: {
    name: 'Basic'
  }
  properties: {
    adminUserEnabled: true
    policies: {
      exportPolicy: {
        status: 'enabled'
      }
      quarantinePolicy: {
        status: 'disabled'
      }
      retentionPolicy: {
        status: 'disabled'
      }
      trustPolicy: {
        status: 'disabled'
      }
    }
    encryption: {
      status: 'disabled'
    }
    dataEndpointEnabled: false
    publicNetworkAccess: 'Enabled'
    networkRuleBypassOptions: 'AzureServices'
  }
}

// Grant ACR Pull permissions to managed identity
resource acrPullRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: containerRegistry
  name: guid(containerRegistry.id, managedIdentity.id, 'AcrPull')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '7f951dda-4ed3-4680-a7ca-43fe172d538d') // AcrPull
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Create Azure Cache for Redis (replaces both Redis and KVrocks)
resource redisCache 'Microsoft.Cache/redis@2024-11-01' = {
  name: resourceNames.redisCache
  location: location
  tags: {
    'azd-env-name': environmentName
  }  
  properties: {
    sku: {
      name: 'Basic'
      family: 'C'
      capacity: 1
    }
    enableNonSslPort: false
    minimumTlsVersion: '1.2'
    publicNetworkAccess: 'Enabled'
  }
}

// Configure comprehensive monitoring for Redis Cache
resource redisDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: redisCache
  name: 'redis-diagnostic-settings'
  properties: {
    workspaceId: logAnalytics.id
    metrics: [
      {
        category: 'AllMetrics'
        enabled: true
      }
    ]
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// Create Redis High CPU Alert
resource redisHighCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'redis-high-cpu-alert'
  location: 'global'
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    description: 'Alert when Redis CPU usage is above 80%'
    severity: 2
    enabled: true
    scopes: [
      redisCache.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCpuUsage'
          metricName: 'PercentProcessorTime'
          metricNamespace: 'Microsoft.Cache/redis'
          operator: 'GreaterThan'
          threshold: 80
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

// Create Redis High Memory Alert
resource redisHighMemoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'redis-high-memory-alert'
  location: 'global'
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    description: 'Alert when Redis memory usage is above 85%'
    severity: 1
    enabled: true
    scopes: [
      redisCache.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighMemoryUsage'
          metricName: 'UsedMemoryPercentage'
          metricNamespace: 'Microsoft.Cache/redis'
          operator: 'GreaterThan'
          threshold: 85
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

// Create Redis Connection Spike Alert
resource redisConnectionAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'redis-connection-spike-alert'
  location: 'global'
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    description: 'Alert when Redis has high number of connected clients'
    severity: 2
    enabled: true
    scopes: [
      redisCache.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT15M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.SingleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighConnections'
          metricName: 'ConnectedClients'
          metricNamespace: 'Microsoft.Cache/redis'
          operator: 'GreaterThan'
          threshold: 100
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

// Create Storage Account for persistent data (file shares)
resource storageAccount 'Microsoft.Storage/storageAccounts@2023-05-01' = {
  name: resourceNames.storageAccount
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  kind: 'StorageV2'
  sku: {
    name: 'Standard_LRS'
  }
  properties: {
    supportsHttpsTrafficOnly: true
    minimumTlsVersion: 'TLS1_2'
    allowBlobPublicAccess: false
    allowSharedKeyAccess: true
    networkAcls: {
      defaultAction: 'Allow'
    }
  }
}

// Create file share for AIL data persistence
resource fileShare 'Microsoft.Storage/storageAccounts/fileServices/shares@2023-05-01' = {
  name: '${storageAccount.name}/default/aildata'
  properties: {
    shareQuota: 100
    enabledProtocols: 'SMB'
  }
}

// Create blob container for AIL data storage (modern approach)
resource blobContainer 'Microsoft.Storage/storageAccounts/blobServices/containers@2023-05-01' = {
  name: '${storageAccount.name}/default/aildata'
  properties: {
    publicAccess: 'None'
  }
}

// Grant Storage File Data SMB Share Contributor to managed identity
resource storageFileDataSmbShareContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, managedIdentity.id, 'StorageFileDataSmbShareContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '0c867c2a-1d8c-454a-a3db-ab2ea1bdc8bb') // Storage File Data SMB Share Contributor
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Grant Storage Blob Data Contributor to managed identity for modern blob access
resource storageBlobDataContributorRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: storageAccount
  name: guid(storageAccount.id, managedIdentity.id, 'StorageBlobDataContributor')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', 'ba92f5b4-2d11-453d-a403-e96b0029c9fe') // Storage Blob Data Contributor
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Create Key Vault for storing secrets
resource keyVault 'Microsoft.KeyVault/vaults@2023-07-01' = {
  name: resourceNames.keyVault
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    sku: {
      family: 'A'
      name: 'standard'
    }
    tenantId: tenant().tenantId
    enableRbacAuthorization: true
    enableSoftDelete: true
    softDeleteRetentionInDays: 7
    networkAcls: {
      defaultAction: 'Allow'
      bypass: 'AzureServices'
    }
  }
}

// Grant Key Vault Secrets User to managed identity
resource keyVaultSecretsUserRole 'Microsoft.Authorization/roleAssignments@2022-04-01' = {
  scope: keyVault
  name: guid(keyVault.id, managedIdentity.id, 'KeyVaultSecretsUser')
  properties: {
    roleDefinitionId: subscriptionResourceId('Microsoft.Authorization/roleDefinitions', '4633458b-17de-408a-b874-0445c86b69e6') // Key Vault Secrets User
    principalId: managedIdentity.properties.principalId
    principalType: 'ServicePrincipal'
  }
}

// Store Redis connection string in Key Vault
resource redisConnectionStringSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'redis-connection-string'
  properties: {
    value: 'rediss://:${redisCache.listKeys().primaryKey}@${redisCache.properties.hostName}:${redisCache.properties.sslPort}'
  }
}

// Store Redis password in Key Vault
resource redisPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'redis-password'
  properties: {
    value: redisCache.listKeys().primaryKey
  }
}

// Store ACR credentials in Key Vault
resource acrUsernameSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'acr-username'
  properties: {
    value: containerRegistry.listCredentials().username
  }
}

resource acrPasswordSecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'acr-password'
  properties: {
    value: containerRegistry.listCredentials().passwords[0].value
  }
}

// Store Storage Account key in Key Vault
resource storageAccountKeySecret 'Microsoft.KeyVault/vaults/secrets@2023-07-01' = {
  parent: keyVault
  name: 'storage-account-key'
  properties: {
    value: storageAccount.listKeys().keys[0].value
  }
}

// Create Container Apps Environment
resource containerAppsEnvironment 'Microsoft.App/managedEnvironments@2024-03-01' = {  name: resourceNames.containerAppsEnvironment
  location: location
  tags: {
    'azd-env-name': environmentName
  }
  properties: {    appLogsConfiguration: {
      destination: 'log-analytics'
      logAnalyticsConfiguration: {
        customerId: logAnalytics.properties.customerId
        #disable-next-line secure-secrets-in-params
        sharedKey: logAnalytics.listKeys().primarySharedKey
      }
    }
  }
}

// Create AIL Framework Container App (public-facing)
resource ailApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: resourceNames.ailApp
  location: location
  tags: {
    'azd-env-name': environmentName
    'azd-service-name': 'ail' // Changed from ail-app
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {
      ingress: {
        external: true
        targetPort: 7000
        transport: 'http'        
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
          allowedHeaders: ['*']
          allowCredentials: false        }
        // IP Security Restrictions (if enabled)
        ipSecurityRestrictions: enableIPRestriction ? ipSecurityRestrictions : []
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: managedIdentity.id
        }
      ]
      secrets: [
        {
          name: 'redis-password'
          keyVaultUrl: redisPasswordSecret.properties.secretUri
          identity: managedIdentity.id        }
        {
          name: 'storage-account-key'
          keyVaultUrl: storageAccountKeySecret.properties.secretUri
          identity: managedIdentity.id
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
      containers: [
        {
          name: 'ail'
          image: ailImage
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          env: [            {
              name: 'LACUS_URL'
              value: 'https://${lacusApp.properties.configuration.ingress.fqdn}'
            }
            // Redis Cache configuration  
            {
              name: 'REDIS_CACHE_HOST'
              value: redisCache.properties.hostName
            }
            {
              name: 'REDIS_CACHE_PORT'
              value: '6380'
            }
            {
              name: 'REDIS_CACHE_PASSWORD'
              secretRef: 'redis-password'
            }
            {
              name: 'REDIS_CACHE_SSL'
              value: 'true'
            }
            // Redis Log configuration
            {
              name: 'REDIS_LOG_HOST'
              value: redisCache.properties.hostName
            }
            {
              name: 'REDIS_LOG_PORT'
              value: '6380'
            }
            {
              name: 'REDIS_LOG_PASSWORD'
              secretRef: 'redis-password'
            }
            {
              name: 'REDIS_LOG_SSL'
              value: 'true'
            }
            // Redis Work/Queues configuration
            {
              name: 'REDIS_WORK_HOST'
              value: redisCache.properties.hostName
            }
            {
              name: 'REDIS_WORK_PORT'
              value: '6380'
            }
            {
              name: 'REDIS_WORK_PASSWORD'
              secretRef: 'redis-password'
            }
            {
              name: 'REDIS_WORK_SSL'
              value: 'true'
            }
            // KVRocks configuration (using Redis as replacement)
            {
              name: 'KVROCKS_HOST'
              value: redisCache.properties.hostName
            }
            {
              name: 'KVROCKS_PORT'
              value: '6380'            }
            {
              name: 'KVROCKS_PASSWORD'
              secretRef: 'redis-password'
            }
            {
              name: 'KVROCKS_SSL'
              value: 'true'
            }
            {
              name: 'AZURE_STORAGE_ACCOUNT_NAME'
              value: storageAccount.name
            }
            {
              name: 'AZURE_STORAGE_ACCOUNT_URL'
              value: storageAccount.properties.primaryEndpoints.blob
            }
            {
              name: 'AZURE_STORAGE_CONTAINER_NAME'
              value: 'aildata'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: managedIdentity.properties.clientId
            }
          ]        }
      ]
    }
  }
}

// Create Lacus Crawler Container App (internal-only)
resource lacusApp 'Microsoft.App/containerApps@2024-03-01' = {
  name: resourceNames.lacusApp
  location: location
  tags: {
    'azd-env-name': environmentName
    'azd-service-name': 'lacus'
  }
  identity: {
    type: 'UserAssigned'
    userAssignedIdentities: {
      '${managedIdentity.id}': {}
    }
  }
  properties: {
    environmentId: containerAppsEnvironment.id
    configuration: {      
      ingress: {
        external: false
        targetPort: 7100
        transport: 'http'
        corsPolicy: {
          allowedOrigins: ['*']
          allowedMethods: ['GET', 'POST', 'PUT', 'DELETE', 'OPTIONS']
          allowedHeaders: ['*']
          allowCredentials: false
        }
      }
      registries: [
        {
          server: containerRegistry.properties.loginServer
          identity: managedIdentity.id
        }
      ]
      secrets: [        {
          name: 'redis-password'
          keyVaultUrl: redisPasswordSecret.properties.secretUri
          identity: managedIdentity.id
        }
        {
          name: 'storage-account-key'
          keyVaultUrl: storageAccountKeySecret.properties.secretUri
          identity: managedIdentity.id
        }
      ]
    }
    template: {
      scale: {
        minReplicas: 1
        maxReplicas: 10
        rules: [
          {
            name: 'http-rule'
            http: {
              metadata: {
                concurrentRequests: '100'
              }
            }
          }
        ]
      }
      containers: [
        {
          name: 'lacus'
          image: lacusImage
          resources: {
            cpu: json('1.0')
            memory: '2Gi'
          }
          env: [
            {
              name: 'REDIS_CACHE_HOST'
              value: redisCache.properties.hostName
            }
            {
              name: 'REDIS_CACHE_PORT'
              value: '6380'
            }
            {
              name: 'REDIS_CACHE_PASSWORD'
              secretRef: 'redis-password'
            }
            {
              name: 'REDIS_HOST'
              value: redisCache.properties.hostName
            }
            {
              name: 'REDIS_PORT'
              value: '6380'            }
            {
              name: 'REDIS_SSL'
              value: 'true'
            }
            {
              name: 'REDIS_PASSWORD'
              secretRef: 'redis-password'
            }
            {
              name: 'AZURE_STORAGE_ACCOUNT_NAME'
              value: storageAccount.name
            }
            {
              name: 'AZURE_STORAGE_ACCOUNT_URL'
              value: storageAccount.properties.primaryEndpoints.blob
            }
            {
              name: 'AZURE_STORAGE_CONTAINER_NAME'
              value: 'aildata'
            }
            {
              name: 'AZURE_CLIENT_ID'
              value: managedIdentity.properties.clientId
            }
          ]        
        }
      ]
    }
  }
}

// Configure monitoring for Storage Account
resource storageDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: storageAccount
  name: 'storage-diagnostic-settings'
  properties: {
    workspaceId: logAnalytics.id
    metrics: [
      {
        category: 'Transaction'
        enabled: true
      }
      {
        category: 'Capacity'
        enabled: true
      }
    ]
  }
}

// Configure monitoring for Container Apps Environment
resource containerEnvDiagnosticSettings 'Microsoft.Insights/diagnosticSettings@2021-05-01-preview' = {
  scope: containerAppsEnvironment
  name: 'container-env-diagnostic-settings'
  properties: {
    workspaceId: logAnalytics.id
    logs: [
      {
        categoryGroup: 'allLogs'
        enabled: true
      }
    ]
  }
}

// TODO: Container Apps alerts currently commented out due to Azure limitation
// ERROR: "Alerts are currently not supported with multi resource level for microsoft.app/containerapps"
// SOLUTION: Need to create separate alerts for each Container App instead of multi-resource alerts
// IMPACT: Will need 4 separate alerts (2 CPU + 2 Memory) for ail and lacus apps individually
// REFERENCE: https://docs.microsoft.com/en-us/azure/azure-monitor/alerts/alerts-metric

/*
// Create Container Apps CPU Alert
resource containerAppsCpuAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'container-apps-high-cpu-alert'
  location: 'global'
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    description: 'Alert when Container Apps CPU usage is above 80%'
    severity: 2
    enabled: true
    scopes: [
      ailApp.id
      lacusApp.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighCpuUsage'
          metricName: 'UsageNanoCores'
          metricNamespace: 'Microsoft.App/containerapps'
          operator: 'GreaterThan'
          threshold: 800000000 // 80% of 1 CPU core in nanocores
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}

// Create Container Apps Memory Alert
resource containerAppsMemoryAlert 'Microsoft.Insights/metricAlerts@2018-03-01' = {
  name: 'container-apps-high-memory-alert'
  location: 'global'
  tags: {
    'azd-env-name': environmentName
  }
  properties: {
    description: 'Alert when Container Apps memory usage is above 85%'
    severity: 2
    enabled: true
    scopes: [
      ailApp.id
      lacusApp.id
    ]
    evaluationFrequency: 'PT5M'
    windowSize: 'PT5M'
    criteria: {
      'odata.type': 'Microsoft.Azure.Monitor.MultipleResourceMultipleMetricCriteria'
      allOf: [
        {
          name: 'HighMemoryUsage'
          metricName: 'WorkingSetBytes'
          metricNamespace: 'Microsoft.App/containerapps'
          operator: 'GreaterThan'
          threshold: 1717986918 // 85% of 2GB in bytes
          timeAggregation: 'Average'
          criterionType: 'StaticThresholdCriterion'
        }
      ]
    }
  }
}
*/

// Outputs for use by other tools and for reference
output AZURE_CONTAINER_REGISTRY_ENDPOINT string = containerRegistry.properties.loginServer
output AZURE_CONTAINER_REGISTRY_NAME string = containerRegistry.name
output AZURE_CONTAINER_APPS_ENVIRONMENT_ID string = containerAppsEnvironment.id
output AZURE_CONTAINER_APPS_ENVIRONMENT_NAME string = containerAppsEnvironment.name
output AZURE_REDIS_CONNECTION_STRING string = '@Microsoft.KeyVault(VaultName=${keyVault.name};SecretName=redis-connection-string)'
output AZURE_STORAGE_ACCOUNT_NAME string = storageAccount.name
output AZURE_FILE_SHARE_NAME string = fileShare.name
output AZURE_KEY_VAULT_NAME string = keyVault.name
output AIL_APP_URL string = 'https://${ailApp.properties.configuration.ingress.fqdn}'
output LACUS_URL string = 'https://${lacusApp.properties.configuration.ingress.fqdn}'
output RESOURCE_GROUP_ID string = resourceGroup().id
