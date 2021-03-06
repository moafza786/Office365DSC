[CmdletBinding()]
param(
    [Parameter()]
    [string]
    $CmdletModule = (Join-Path -Path $PSScriptRoot `
            -ChildPath "..\Stubs\Office365.psm1" `
            -Resolve)
)

$GenericStubPath = (Join-Path -Path $PSScriptRoot `
    -ChildPath "..\Stubs\Generic.psm1" `
    -Resolve)
Import-Module -Name (Join-Path -Path $PSScriptRoot `
        -ChildPath "..\UnitTestHelper.psm1" `
        -Resolve)

$Global:DscHelper = New-O365DscUnitTestHelper -StubModule $CmdletModule `
    -DscResource "EXOAcceptedDomain" -GenericStubModule $GenericStubPath
Describe -Name $Global:DscHelper.DescribeHeader -Fixture {
    InModuleScope -ModuleName $Global:DscHelper.ModuleName -ScriptBlock {
        Invoke-Command -ScriptBlock $Global:DscHelper.InitializeScript -NoNewScope

        $secpasswd = ConvertTo-SecureString "test@password1" -AsPlainText -Force
        $GlobalAdminAccount = New-Object System.Management.Automation.PSCredential ("tenantadmin", $secpasswd)

        Mock -CommandName Close-SessionsAndReturnError -MockWith {

        }

        Mock -CommandName Test-MSCloudLogin -MockWith {

        }

        Mock -CommandName Get-PSSession -MockWith {

        }

        Mock -CommandName Remove-PSSession -MockWith {

        }

        # Test contexts
        Context -Name "Authoritative Accepted Domain should exist.  Domain is missing. Test should fail." -Fixture {
            $testParams = @{
                DomainType         = 'Authoritative'
                Ensure             = 'Present'
                GlobalAdminAccount = $GlobalAdminAccount
                Identity           = 'contoso.com'
            }

            Mock -CommandName Get-AzureADDomain -MockWith {
                return @{
                    Name       = 'different.contoso.com'
                    IsVerified = $true
                }
            }

            Mock -CommandName Get-AcceptedDomain -MockWith {
                return @{
                    DomainType      = 'Authoritative'
                    Identity        = 'different.contoso.com'
                    MatchSubDomains = $false
                    OutboundOnly    = $false
                }
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should Be $false
            }

            Mock -CommandName Set-AcceptedDomain -MockWith {
                return @{
                    DomainType         = 'Authoritative'
                    Ensure             = 'Present'
                    GlobalAdminAccount = $GlobalAdminAccount
                    Identity           = 'contoso.com'
                }
            }

            It "Should call the Set method" {
                Set-TargetResource @testParams
            }

            It "Should return Absent from the Get method" {
                (Get-TargetResource @testParams).Ensure | Should Be "Absent"
            }
        }

        Context -Name "Verified domain doesn't exist in the tenant." -Fixture {
            $testParams = @{
                DomainType         = 'Authoritative'
                Ensure             = 'Absent'
                MatchSubDomain     = $false
                OutboundOnly       = $false
                GlobalAdminAccount = $GlobalAdminAccount
                Identity           = 'contoso.com'
            }

            Mock -CommandName Get-AcceptedDomain -MockWith {
                return @{
                    DomainType      = 'Authoritative'
                    Identity        = 'different.tailspin.com'
                    MatchSubDomains = $false
                    OutboundOnly    = $false
                }
            }

            Mock -CommandName Get-AzureADDomain -MockWith {
                return @{
                    Name       = 'contoso.com'
                    IsVerified = $true
                }
            }

            It "Should return Absent from the Get method" {
                (Get-TargetResource @testParams).Ensure | Should Be "Absent"
            }
        }

        Context -Name "Authoritative Accepted Domain should exist.  Domain exists. Test should pass." -Fixture {
            $testParams = @{
                DomainType         = 'Authoritative'
                Ensure             = 'Present'
                MatchSubDomain     = $false
                OutboundOnly       = $false
                GlobalAdminAccount = $GlobalAdminAccount
                Identity           = 'contoso.com'
            }

            Mock -CommandName Get-AzureADDomain -MockWith {
                return @{
                    Name       = 'contoso.com'
                    IsVerified = $true
                }

            }

            Mock -CommandName Get-AcceptedDomain -MockWith {
                return @{
                    DomainType      = 'Authoritative'
                    Identity        = 'contoso.com'
                    MatchSubDomains = $false
                    OutboundOnly    = $false
                }
            }

            It 'Should return true from the Test method' {
                Test-TargetResource @testParams | Should Be $true
            }

            It 'Should return Present from the Get Method' {
                (Get-TargetResource @testParams).Ensure | Should Be "Present"
            }
        }

        Context -Name "Authoritative Accepted Domain should exist.  Domain exists, DomainType and MatchSubDomains mismatch. Test should fail." -Fixture {
            $testParams = @{
                DomainType         = 'Authoritative'
                Ensure             = 'Present'
                GlobalAdminAccount = $GlobalAdminAccount
                Identity           = 'contoso.com'
            }

            Mock -CommandName Get-AzureADDomain -MockWith {
                return @{
                    Name       = 'contoso.com'
                    IsVerified = $true
                }

            }

            Mock -CommandName Get-AcceptedDomain -MockWith {
                return @{
                    DomainType      = 'InternalRelay'
                    Identity        = 'contoso.com'
                    MatchSubDomains = $true
                    OutboundOnly    = $false
                }
            }

            It 'Should return false from the Test method' {
                Test-TargetResource @testParams | Should Be $false
            }

            Mock -CommandName Set-AcceptedDomain -MockWith {

            }

            Mock -CommandName Set-AcceptedDomain -MockWith {
                return @{
                    DomainType         = 'Authoritative'
                    Ensure             = 'Present'
                    GlobalAdminAccount = $GlobalAdminAccount
                    Identity           = 'contoso.com'
                }
            }

            It "Should call the Set method" {
                Set-TargetResource @testParams
            }
        }

        Context -Name "ReverseDSC Tests" -Fixture {
            $testParams = @{
                GlobalAdminAccount = $GlobalAdminAccount
            }

            $acceptedDomain1 = @{
                DomainType      = 'Authoritative'
                Identity        = 'different1.tailspin.com'
                MatchSubDomains = $false
                OutboundOnly    = $false
            }

            $acceptedDomain2 = @{
                DomainType      = 'Authoritative'
                Identity        = 'different2.tailspin.com'
                MatchSubDomains = $false
                OutboundOnly    = $false
            }

            It "Should Reverse Engineer resource from the Export method when single" {
                Mock -CommandName Get-AcceptedDomain -MockWith {
                    return $acceptedDomain1
                }

                $exported = Export-TargetResource @testParams
                ([regex]::Matches($exported, " EXOAcceptedDomain " )).Count | Should Be 1
                $exported.Contains("different1.tailspin.com") | Should Be $true
            }

            It "Should Reverse Engineer resource from the Export method when multiple" {
                Mock -CommandName Get-AcceptedDomain -MockWith {
                    return @($acceptedDomain1, $acceptedDomain2)
                }

                $exported = Export-TargetResource @testParams
                ([regex]::Matches($exported, " EXOAcceptedDomain " )).Count | Should Be 2
                $exported.Contains("different2.tailspin.com") | Should Be $true
            }
        }
    }
}

Invoke-Command -ScriptBlock $Global:DscHelper.CleanupScript -NoNewScope
