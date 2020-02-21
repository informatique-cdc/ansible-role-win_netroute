# Molecule managed
FROM microsoft/windowsservercore:latest
RUN powershell.exe -Command \
    wget https://raw.githubusercontent.com/ansible/ansible/devel/examples/scripts/ConfigureRemotingForAnsible.ps1 -Proxy <proxy> -Outfile c:\remoting.ps1; \
    powershell.exe -ExecutionPolicy ByPass -File c:\remoting.ps1 -EnableCredSSP; \
    $password = ConvertTo-SecureString "<password>" -AsPlainText -Force; \
    Set-LocalUser -Name administrator -Password $password; \
    Enable-LocalUser -Name "Administrator"; \
    Dism.exe /online /Cleanup-Image /StartComponentCleanup /ResetBase
EXPOSE 5986