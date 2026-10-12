[CmdletBinding(SupportsShouldProcess)]
param()

$ErrorActionPreference = 'Stop'
$argocdNamespace = 'argocd'

function Invoke-ClusterCommand {
    param(
        [Parameter(Mandatory)]
        [string]$FilePath,

        [Parameter(Mandatory)]
        [string[]]$ArgumentList,

        [Parameter(Mandatory)]
        [string]$Description
    )

    if ($PSCmdlet.ShouldProcess($Description, "$FilePath $($ArgumentList -join ' ')")) {
        & $FilePath @ArgumentList
        if ($LASTEXITCODE -ne 0) {
            throw "Command failed with exit code $LASTEXITCODE`: $FilePath $($ArgumentList -join ' ')"
        }
    }
}

# 1. Create ArgoCD Namespace
Write-Host "--> [1/4] Creating ArgoCD namespace '$argocdNamespace'..."
Invoke-ClusterCommand 'kubectl' @('apply', '-f', 'kubernetes/config/argocd-namespace.yaml') 'Create ArgoCD namespace'
Write-Host 'ArgoCD namespace successfully applied to the cluster!'

# 2. Create Secrets in the Cluster
Write-Host '--> [2/4] Creating Secrets...'
Invoke-ClusterCommand 'helm' @('upgrade', '--install', 'credentials', 'kubernetes/credentials', '-f', 'kubernetes/credentials/values.yml') 'Install credentials chart'
Write-Host 'All secrets successfully injected into the cluster!'

# 3. Install ArgoCD in the Cluster
Write-Host "--> [3/4] Installing ArgoCD into namespace '$argocdNamespace'..."
Invoke-ClusterCommand 'kubectl' @('apply', '-n', $argocdNamespace, '--server-side', '--force-conflicts', '-f', 'kubernetes/config/argocd.yaml') 'Install ArgoCD'
Write-Host 'ArgoCD successfully created in the cluster!'

# 4. Deploy the Argo CD Root Application
Write-Host '--> [4/4] Deploying ArgoCD Application...'
Invoke-ClusterCommand 'kubectl' @('apply', '-f', 'kubernetes/config/application.yaml') 'Deploy ArgoCD application'

Write-Host ''
Write-Host '=========================================='
Write-Host 'Cluster bootstrap completed!'
Write-Host 'Argo CD is now syncing your stack.'
Write-Host '=========================================='