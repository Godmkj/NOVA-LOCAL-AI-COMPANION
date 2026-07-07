Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase
Add-Type -AssemblyName System.Xaml
Add-Type -AssemblyName System.Drawing
Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName WindowsFormsIntegration
Add-Type -AssemblyName Microsoft.VisualBasic

try { Add-Type -AssemblyName System.Speech } catch {}

$Root = Split-Path -Parent $MyInvocation.MyCommand.Path
$OllamaExe = Join-Path $env:LOCALAPPDATA "Programs\Ollama\ollama.exe"
$PiperExe = Join-Path $Root "backend\bin\piper\piper\piper.exe"
$PiperVoice = Join-Path $Root "backend\voices\piper\en_US-amy-medium.onnx"
$VoiceOut = Join-Path $Root "backend\data\nova_reply.wav"
$GifPath = Join-Path $Root "assets\nova_orb.gif"
$KnowledgeDir = Join-Path $Root "backend\data\knowledge"
New-Item -ItemType Directory -Force $KnowledgeDir | Out-Null

$script:Recognizer = $null
$script:MicActive = $false
$script:VoiceEnabled = $true
$script:ShowText = $true
$script:PerformanceMode = $true
$script:ListeningForResponse = $false
$script:StatsFrame = 0
$script:WaveFrame = 0
$script:ResponseJob = $null
$script:SpeakingUntil = Get-Date

$xaml = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        xmlns:wfi="clr-namespace:System.Windows.Forms.Integration;assembly=WindowsFormsIntegration"
        Title="NOVA Desktop Companion" Width="1360" Height="780"
        WindowStartupLocation="CenterScreen" Background="#02070A">
    <Window.Resources>
        <Style TargetType="Border" x:Key="Panel">
            <Setter Property="Background" Value="#AA0B171D"/>
            <Setter Property="BorderBrush" Value="#304DEBFF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="CornerRadius" Value="8"/>
            <Setter Property="Padding" Value="14"/>
            <Setter Property="Margin" Value="0,0,0,12"/>
        </Style>
        <Style TargetType="TextBlock">
            <Setter Property="Foreground" Value="#DDFBFF"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
        </Style>
        <Style TargetType="Button">
            <Setter Property="Background" Value="#12242C"/>
            <Setter Property="Foreground" Value="#DDFBFF"/>
            <Setter Property="BorderBrush" Value="#4DEBFF"/>
            <Setter Property="BorderThickness" Value="1"/>
            <Setter Property="Padding" Value="10,8"/>
            <Setter Property="Cursor" Value="Hand"/>
        </Style>
        <Style TargetType="CheckBox">
            <Setter Property="Foreground" Value="#DDFBFF"/>
            <Setter Property="FontFamily" Value="Segoe UI"/>
        </Style>
    </Window.Resources>
    <Grid>
        <Grid.Background>
            <LinearGradientBrush StartPoint="0,0" EndPoint="1,1">
                <GradientStop Color="#02070A" Offset="0"/>
                <GradientStop Color="#06131A" Offset="0.52"/>
                <GradientStop Color="#020409" Offset="1"/>
            </LinearGradientBrush>
        </Grid.Background>

        <Grid.RowDefinitions>
            <RowDefinition Height="58"/>
            <RowDefinition Height="*"/>
        </Grid.RowDefinitions>

        <Border Grid.Row="0" BorderBrush="#203BEAFF" BorderThickness="0,0,0,1" Padding="18,0">
            <DockPanel LastChildFill="False">
                <StackPanel Orientation="Horizontal" DockPanel.Dock="Left" VerticalAlignment="Center">
                    <TextBlock Text="NOVA" Foreground="#86F7FF" FontSize="22" FontWeight="Bold"/>
                    <TextBlock Text=" LOCAL AI OPERATING COMPANION" Foreground="#5D8E9A" FontSize="11" Margin="12,7,0,0"/>
                    <Border Background="#173420" BorderBrush="#4080FFB0" BorderThickness="1" CornerRadius="5" Margin="12,0,0,0" Padding="8,4">
                        <TextBlock x:Name="StatusText" Text="LOCAL DESKTOP" Foreground="#40FFB0" FontSize="11" FontWeight="Bold"/>
                    </Border>
                </StackPanel>
                <StackPanel Orientation="Horizontal" DockPanel.Dock="Right" VerticalAlignment="Center">
                    <Border Background="#66101D24" BorderBrush="#263BEAFF" BorderThickness="1" CornerRadius="6" Padding="10,6" Margin="0,0,8,0">
                        <TextBlock x:Name="ClockText" Text="--:--:--" Foreground="#DDFBFF" FontSize="12"/>
                    </Border>
                    <Button x:Name="OrbModeButton" Content="Compact" Width="96"/>
                </StackPanel>
            </DockPanel>
        </Border>

        <Grid Grid.Row="1" Margin="14">
            <Grid.ColumnDefinitions>
                <ColumnDefinition Width="300"/>
                <ColumnDefinition Width="*"/>
                <ColumnDefinition Width="390"/>
            </Grid.ColumnDefinitions>

            <ScrollViewer Grid.Column="0" VerticalScrollBarVisibility="Auto">
                <StackPanel>
                    <Border Style="{StaticResource Panel}">
                        <StackPanel>
                            <TextBlock Text="SYSTEM ANALYTICS" Foreground="#7EF6FF" FontWeight="Bold" FontSize="13"/>
                            <TextBlock x:Name="CpuText" Text="CPU Engine     --" Margin="0,14,0,3"/>
                            <ProgressBar x:Name="CpuBar" Value="18" Height="6" Foreground="#41E9FF" Background="#0B2028"/>
                            <TextBlock x:Name="MemText" Text="Memory         --" Margin="0,12,0,3"/>
                            <ProgressBar x:Name="MemBar" Value="42" Height="6" Foreground="#41E9FF" Background="#0B2028"/>
                            <TextBlock x:Name="OllamaText" Text="Ollama         checking..." Margin="0,12,0,0" Foreground="#A9D9E2"/>
                        </StackPanel>
                    </Border>
                    <Border Style="{StaticResource Panel}">
                        <StackPanel>
                            <TextBlock Text="TRAIN NOVA" Foreground="#7EF6FF" FontWeight="Bold" FontSize="13"/>
                            <Button x:Name="UploadDocsButton" Content="+ Upload PDFs / DOCX / Notes" Margin="0,12,0,0"/>
                            <Button x:Name="WebsiteButton" Content="+ Add website knowledge" Margin="0,8,0,0"/>
                            <Button x:Name="WorkflowButton" Content="+ Teach workflow" Margin="0,8,0,0"/>
                            <Button x:Name="RuleButton" Content="+ Add private rule" Margin="0,8,0,0"/>
                        </StackPanel>
                    </Border>
                    <Border Style="{StaticResource Panel}">
                        <StackPanel>
                            <TextBlock Text="LOCAL VOICE" Foreground="#7EF6FF" FontWeight="Bold" FontSize="13"/>
                            <TextBlock x:Name="VoiceText" Text="Piper Amy female voice ready" Margin="0,12,0,0" Foreground="#A9D9E2" TextWrapping="Wrap"/>
                            <TextBlock Text="Mic mode: continuous Windows dictation" Margin="0,8,0,0" Foreground="#6FAAB8" TextWrapping="Wrap"/>
                            <Button x:Name="TestVoiceButton" Content="Test voice" Margin="0,12,0,0"/>
                        </StackPanel>
                    </Border>
                </StackPanel>
            </ScrollViewer>

            <Grid Grid.Column="1" Margin="18,0">
                <Grid.RowDefinitions>
                    <RowDefinition Height="*"/>
                    <RowDefinition Height="70"/>
                </Grid.RowDefinitions>

                <Grid Grid.Row="0" Background="#000000" ClipToBounds="True">
                    <Grid.RowDefinitions>
                        <RowDefinition Height="64"/>
                        <RowDefinition Height="*"/>
                        <RowDefinition Height="46"/>
                        <RowDefinition Height="58"/>
                    </Grid.RowDefinitions>

                    <StackPanel Grid.Row="0" HorizontalAlignment="Center" VerticalAlignment="Center">
                        <TextBlock Text="N.O.V.A." HorizontalAlignment="Center" Foreground="#EAFDFF" FontSize="26" FontWeight="Bold"/>
                        <TextBlock Text="LOCAL VOICE INTELLIGENCE" HorizontalAlignment="Center" Foreground="#5D8E9A" FontSize="10" Margin="0,3,0,0"/>
                    </StackPanel>

                    <Border Grid.Row="1" Background="#000000" ClipToBounds="True">
                        <wfi:WindowsFormsHost x:Name="GifHost" Margin="0"/>
                    </Border>

                    <Grid Grid.Row="2">
                        <Canvas x:Name="WaveCanvas" Height="38" Width="260" HorizontalAlignment="Center" VerticalAlignment="Center" IsHitTestVisible="False"/>
                        <Border Background="#BB071015" BorderBrush="#224DEBFF" BorderThickness="1" CornerRadius="5" Padding="10,5" HorizontalAlignment="Center" VerticalAlignment="Bottom">
                            <TextBlock x:Name="ListenText" Text="Voice bridge ready" Foreground="#7EF6FF" FontSize="12"/>
                        </Border>
                    </Grid>

                    <StackPanel Grid.Row="3" Orientation="Horizontal" HorizontalAlignment="Center" VerticalAlignment="Center">
                        <Button x:Name="MicButton" Content="Start Mic" Width="100" Margin="0,0,12,0"/>
                        <Button x:Name="CameraButton" Content="Camera" Width="100" Margin="0,0,12,0"/>
                        <Button x:Name="KeyboardButton" Content="Keyboard" Width="100"/>
                    </StackPanel>
                </Grid>

                <Border Grid.Row="1" Background="#99101A20" BorderBrush="#334DEBFF" BorderThickness="1" CornerRadius="8" Padding="10">
                    <DockPanel>
                        <Button x:Name="SendButton" Content="Send" Width="76" DockPanel.Dock="Right" Margin="10,0,0,0"/>
                        <TextBox x:Name="PromptBox" Background="#00101A20" Foreground="#EAFDFF" BorderBrush="#224DEBFF" FontSize="14" Padding="12" VerticalContentAlignment="Center"/>
                    </DockPanel>
                </Border>
            </Grid>

            <Border Grid.Column="2" Style="{StaticResource Panel}" Margin="0">
                <Grid>
                    <Grid.RowDefinitions>
                        <RowDefinition Height="36"/>
                        <RowDefinition Height="86"/>
                        <RowDefinition Height="*"/>
                    </Grid.RowDefinitions>
                    <DockPanel Grid.Row="0">
                        <TextBlock Text="CONVERSATION / VOICE" Foreground="#7EF6FF" FontWeight="Bold" FontSize="13" VerticalAlignment="Center"/>
                        <Button x:Name="ClearButton" Content="Clear" DockPanel.Dock="Right" Width="70"/>
                    </DockPanel>
                    <Border Grid.Row="1" Background="#33101D24" BorderBrush="#224DEBFF" BorderThickness="1" CornerRadius="7" Padding="10" Margin="0,0,0,10">
                        <StackPanel>
                            <CheckBox x:Name="VoiceToggle" Content="Speak answers with AI voice" IsChecked="True" Margin="0,0,0,8"/>
                            <CheckBox x:Name="TextToggle" Content="Show answer text on screen" IsChecked="True" Margin="0,0,0,8"/>
                            <CheckBox x:Name="PerformanceToggle" Content="Performance mode: pause orb while thinking" IsChecked="True"/>
                        </StackPanel>
                    </Border>
                    <ScrollViewer Grid.Row="2" VerticalScrollBarVisibility="Auto">
                        <StackPanel x:Name="ConversationPanel">
                            <Border Background="#33103645" BorderBrush="#3348E8FF" BorderThickness="1" CornerRadius="8" Padding="12" Margin="0,0,0,10">
                                <TextBlock Text="NOVA is running locally. Type, press Mic On, open Camera, upload knowledge, or test the voice." TextWrapping="Wrap"/>
                            </Border>
                        </StackPanel>
                    </ScrollViewer>
                </Grid>
            </Border>
        </Grid>
    </Grid>
</Window>
"@

$reader = New-Object System.Xml.XmlNodeReader ([xml]$xaml)
$Window = [Windows.Markup.XamlReader]::Load($reader)

$StatusText = $Window.FindName("StatusText")
$ClockText = $Window.FindName("ClockText")
$PromptBox = $Window.FindName("PromptBox")
$SendButton = $Window.FindName("SendButton")
$ClearButton = $Window.FindName("ClearButton")
$ConversationPanel = $Window.FindName("ConversationPanel")
$MicButton = $Window.FindName("MicButton")
$CameraButton = $Window.FindName("CameraButton")
$KeyboardButton = $Window.FindName("KeyboardButton")
$OrbModeButton = $Window.FindName("OrbModeButton")
$ListenText = $Window.FindName("ListenText")
$VoiceText = $Window.FindName("VoiceText")
$VoiceToggle = $Window.FindName("VoiceToggle")
$TextToggle = $Window.FindName("TextToggle")
$PerformanceToggle = $Window.FindName("PerformanceToggle")
$TestVoiceButton = $Window.FindName("TestVoiceButton")
$UploadDocsButton = $Window.FindName("UploadDocsButton")
$WebsiteButton = $Window.FindName("WebsiteButton")
$WorkflowButton = $Window.FindName("WorkflowButton")
$RuleButton = $Window.FindName("RuleButton")
$GifHost = $Window.FindName("GifHost")
$WaveCanvas = $Window.FindName("WaveCanvas")
$CpuText = $Window.FindName("CpuText")
$CpuBar = $Window.FindName("CpuBar")
$MemText = $Window.FindName("MemText")
$MemBar = $Window.FindName("MemBar")
$OllamaText = $Window.FindName("OllamaText")

if (Test-Path $OllamaExe) { $OllamaText.Text = "Ollama         llama3.2:1b local" } else { $OllamaText.Text = "Ollama         not found" }
if (-not (Test-Path $PiperExe) -or -not (Test-Path $PiperVoice)) { $VoiceText.Text = "Piper voice files missing" }

if (Test-Path $GifPath) {
    $pictureBox = New-Object System.Windows.Forms.PictureBox
    $pictureBox.Dock = [System.Windows.Forms.DockStyle]::Fill
    $pictureBox.BackColor = [System.Drawing.Color]::Black
    $pictureBox.SizeMode = [System.Windows.Forms.PictureBoxSizeMode]::Zoom
    $pictureBox.Image = [System.Drawing.Image]::FromFile($GifPath)
    $GifHost.Child = $pictureBox
    $script:PictureBox = $pictureBox
} else {
    $ListenText.Text = "Neural GIF missing"
}

function Set-OrbAnimation($Enabled) {
    if (-not $script:PictureBox) { return }
    if ($Enabled) {
        $script:PictureBox.Visible = $true
    } else {
        $script:PictureBox.Visible = $false
    }
}

Set-OrbAnimation $true

function Add-ChatBubble($Text, $IsUser) {
    if (-not $script:ShowText -and -not $IsUser) { return }
    $border = New-Object System.Windows.Controls.Border
    $border.CornerRadius = 8
    $border.Padding = 12
    $border.Margin = "0,0,0,10"
    $border.BorderThickness = 1
    $border.BorderBrush = "#3348E8FF"
    $border.Background = if ($IsUser) { "#33294A64" } else { "#33103645" }

    $block = New-Object System.Windows.Controls.TextBlock
    $block.Text = $Text
    $block.TextWrapping = "Wrap"
    $block.Foreground = "#EAFDFF"
    $border.Child = $block
    [void]$ConversationPanel.Children.Add($border)
}

function Invoke-NovaReply($Prompt) {
    if (Test-Path $OllamaExe) {
        try {
            $system = "You are NOVA, a local privacy-first desktop AI companion. Reply naturally and concisely. Match the user's tone and language. Choose answer depth by weight: simple/chat questions get one direct answer; medium how-to questions may get two options; only complex, high-stakes, planning, coding, or comparison questions get three perspectives. Do not force three answers."
            $reply = & $OllamaExe run llama3.2:1b "$system`nUser: $Prompt`nNOVA:"
            if ($reply) { return ($reply -join "`n").Trim() }
        } catch {
            return "Ollama is installed, but the local model call failed: $($_.Exception.Message)"
        }
    }
    return "Ollama was not reachable. Check that llama3.2:1b is installed and Ollama is running."
}

function Speak-Nova($Text) {
    if (-not $script:VoiceEnabled) { return }
    if (-not (Test-Path $PiperExe) -or -not (Test-Path $PiperVoice)) { return }
    try {
        $Text | & $PiperExe --model $PiperVoice --output_file $VoiceOut | Out-Null
        $player = New-Object System.Media.SoundPlayer $VoiceOut
        $player.Play()
        $script:SpeakingUntil = (Get-Date).AddSeconds(4)
    } catch {
        Add-ChatBubble "VOICE ERROR: $($_.Exception.Message)" $false
    }
}

function Send-NovaPrompt($Prompt) {
    $prompt = $Prompt.Trim()
    if (-not $prompt) { return }
    if ($script:ResponseJob -and $script:ResponseJob.State -eq "Running") {
        Add-ChatBubble "NOVA: I am still finishing the current response." $false
        return
    }
    Add-ChatBubble "YOU: $prompt" $true
    $PromptBox.Text = ""
    $StatusText.Text = "THINKING"
    $ListenText.Text = "Reasoning with llama3.2:1b"
    if ($script:PerformanceMode) { Set-OrbAnimation $false }
    $script:SpeakingUntil = (Get-Date).AddSeconds(2)
    $script:ResponseJob = Start-Job -ArgumentList $prompt,$OllamaExe,$PiperExe,$PiperVoice,$Root,$script:VoiceEnabled -ScriptBlock {
        param($Prompt,$OllamaExe,$PiperExe,$PiperVoice,$Root,$VoiceEnabled)

        $reply = ""
        if (Test-Path $OllamaExe) {
            try {
                $system = "You are NOVA, a local privacy-first desktop AI companion. Reply naturally and concisely. Match the user's tone and language. Choose answer depth by weight: simple/chat questions get one direct answer; medium how-to questions may get two options; only complex, high-stakes, planning, coding, or comparison questions get three perspectives. Do not force three answers."
                $out = & $OllamaExe run llama3.2:1b "$system`nUser: $Prompt`nNOVA:"
                if ($out) { $reply = ($out -join "`n").Trim() }
            } catch {
                $reply = "Ollama is installed, but the local model call failed: $($_.Exception.Message)"
            }
        }
        if (-not $reply) {
            $reply = "Ollama was not reachable. Check that llama3.2:1b is installed and Ollama is running."
        }

        $audioPath = ""
        if ($VoiceEnabled -and (Test-Path $PiperExe) -and (Test-Path $PiperVoice)) {
            try {
                $outDir = Join-Path $Root "backend\data"
                New-Item -ItemType Directory -Force $outDir | Out-Null
                $audioPath = Join-Path $outDir ("nova_reply_" + [Guid]::NewGuid().ToString("N") + ".wav")
                $reply | & $PiperExe --model $PiperVoice --output_file $audioPath | Out-Null
            } catch {
                $audioPath = ""
            }
        }

        [PSCustomObject]@{
            Reply = $reply
            AudioPath = $audioPath
        }
    }
}

function Complete-NovaResponseJob {
    if (-not $script:ResponseJob) { return }
    if ($script:ResponseJob.State -eq "Running") { return }

    try {
        $result = Receive-Job $script:ResponseJob -ErrorAction SilentlyContinue | Select-Object -Last 1
        Remove-Job $script:ResponseJob -Force -ErrorAction SilentlyContinue
        $script:ResponseJob = $null

        if ($result -and $result.Reply) {
            Add-ChatBubble "NOVA: $($result.Reply)" $false
            if ($script:VoiceEnabled -and $result.AudioPath -and (Test-Path $result.AudioPath)) {
                $player = New-Object System.Media.SoundPlayer $result.AudioPath
                $player.Play()
                $script:SpeakingUntil = (Get-Date).AddSeconds(6)
            }
        }
    } catch {
        Add-ChatBubble "NOVA ERROR: $($_.Exception.Message)" $false
    }

    $StatusText.Text = "LOCAL DESKTOP"
    $ListenText.Text = if ($script:MicActive) { "Listening continuously" } else { "Voice bridge ready" }
    Set-OrbAnimation $true
}

function Start-NovaMic {
    if ($script:Recognizer) { return }
    try {
        $script:Recognizer = New-Object System.Speech.Recognition.SpeechRecognitionEngine
        $dictation = New-Object System.Speech.Recognition.DictationGrammar
        $script:Recognizer.LoadGrammar($dictation)
        $script:Recognizer.SetInputToDefaultAudioDevice()
        Register-ObjectEvent -InputObject $script:Recognizer -EventName SpeechRecognized -Action {
            if ($Event.SourceEventArgs.Result -and $Event.SourceEventArgs.Result.Confidence -gt 0.25) {
                $text = $Event.SourceEventArgs.Result.Text
                $Window.Dispatcher.Invoke([Action]{
                    $PromptBox.Text = $text
                    Send-NovaPrompt $text
                })
            } elseif ($Event.SourceEventArgs.Result) {
                $heard = $Event.SourceEventArgs.Result.Text
                $confidence = [Math]::Round($Event.SourceEventArgs.Result.Confidence, 2)
                $Window.Dispatcher.Invoke([Action]{
                    $ListenText.Text = "Heard unclearly: $heard ($confidence)"
                    $PromptBox.Text = $heard
                })
            }
        } | Out-Null
        Register-ObjectEvent -InputObject $script:Recognizer -EventName SpeechHypothesized -Action {
            if ($Event.SourceEventArgs.Result) {
                $partial = $Event.SourceEventArgs.Result.Text
                $Window.Dispatcher.Invoke([Action]{
                    $ListenText.Text = "Hearing: $partial"
                })
            }
        } | Out-Null
        $script:Recognizer.RecognizeAsync([System.Speech.Recognition.RecognizeMode]::Multiple)
        $script:MicActive = $true
        $MicButton.Content = "Stop Mic"
        $ListenText.Text = "Listening continuously"
    } catch {
        $script:Recognizer = $null
        $script:MicActive = $false
        $ListenText.Text = "Mic unavailable. Type instead."
        Add-ChatBubble "MIC ERROR: $($_.Exception.Message)" $false
    }
}

function Stop-NovaMic {
    if ($script:Recognizer) {
        try { $script:Recognizer.RecognizeAsyncCancel() } catch {}
        try { $script:Recognizer.Dispose() } catch {}
    }
    $script:Recognizer = $null
    $script:MicActive = $false
    $MicButton.Content = "Start Mic"
    $ListenText.Text = "Voice bridge ready"
}

function Render-Waveform {
    if (-not $WaveCanvas -or $WaveCanvas.ActualWidth -lt 10) { return }
    $WaveCanvas.Children.Clear()

    $active = $script:MicActive -or ($StatusText.Text -eq "THINKING") -or ((Get-Date) -lt $script:SpeakingUntil)
    if (-not $active) { return }

    $script:WaveFrame += 0.22
    $bars = 22
    $spacing = 12
    $baseX = 18
    $midY = $WaveCanvas.ActualHeight / 2

    for ($i = 0; $i -lt $bars; $i++) {
        $phase = $script:WaveFrame + ($i * 0.55)
        $height = 8 + ([Math]::Abs([Math]::Sin($phase)) * 30)
        if ($StatusText.Text -eq "THINKING") { $height *= 0.55 }

        $line = New-Object System.Windows.Shapes.Line
        $line.X1 = $baseX + ($i * $spacing)
        $line.X2 = $line.X1
        $line.Y1 = $midY - ($height / 2)
        $line.Y2 = $midY + ($height / 2)
        $line.Stroke = "#AA86F7FF"
        $line.StrokeThickness = 2
        $line.StrokeStartLineCap = "Round"
        $line.StrokeEndLineCap = "Round"
        $line.Opacity = 0.35 + ([Math]::Abs([Math]::Sin($phase)) * 0.45)
        [void]$WaveCanvas.Children.Add($line)
    }
}

$SendAction = {
    Send-NovaPrompt $PromptBox.Text
}

$SendButton.Add_Click($SendAction)
$PromptBox.Add_KeyDown({
    if ($_.Key -eq "Return") { & $SendAction }
})
$ClearButton.Add_Click({ $ConversationPanel.Children.Clear() })
$VoiceToggle.Add_Click({ $script:VoiceEnabled = [bool]$VoiceToggle.IsChecked })
$TextToggle.Add_Click({ $script:ShowText = [bool]$TextToggle.IsChecked })
$PerformanceToggle.Add_Click({
    $script:PerformanceMode = [bool]$PerformanceToggle.IsChecked
    if (-not $script:PerformanceMode) { Set-OrbAnimation $true }
})
$TestVoiceButton.Add_Click({ Speak-Nova "Hello, I am NOVA. Local female voice is online." })

$MicButton.Add_Click({
    if ($script:MicActive) { Stop-NovaMic } else { Start-NovaMic }
})
$CameraButton.Add_Click({
    try {
        Start-Process "microsoft.windows.camera:"
        Add-ChatBubble "NOVA: Opening Windows Camera." $false
    } catch {
        Add-ChatBubble "CAMERA ERROR: $($_.Exception.Message)" $false
    }
})
$KeyboardButton.Add_Click({
    $PromptBox.Focus() | Out-Null
    $ListenText.Text = "Keyboard input focused"
})
$OrbModeButton.Add_Click({
    if ($Window.Width -gt 500) {
        $Window.Width = 280
        $Window.Height = 280
        $Window.Topmost = $true
        $Window.WindowStyle = "None"
        $Window.ResizeMode = "NoResize"
        $ListenText.Text = "Floating orb mode"
    } else {
        $Window.Width = 1360
        $Window.Height = 780
        $Window.Topmost = $false
        $Window.WindowStyle = "SingleBorderWindow"
        $Window.ResizeMode = "CanResize"
        $Window.WindowStartupLocation = "CenterScreen"
    }
})

$UploadDocsButton.Add_Click({
    $dialog = New-Object Microsoft.Win32.OpenFileDialog
    $dialog.Multiselect = $true
    $dialog.Filter = "Knowledge files|*.pdf;*.docx;*.txt;*.md|All files|*.*"
    if ($dialog.ShowDialog()) {
        foreach ($file in $dialog.FileNames) {
            Copy-Item -LiteralPath $file -Destination $KnowledgeDir -Force
        }
        Add-ChatBubble "NOVA: Imported $($dialog.FileNames.Count) local knowledge file(s)." $false
    }
})
$WebsiteButton.Add_Click({
    $url = [Microsoft.VisualBasic.Interaction]::InputBox("Paste a website URL for NOVA memory:", "Add Website Knowledge", "https://")
    if ($url -and $url -ne "https://") {
        Add-Content -Path (Join-Path $KnowledgeDir "websites.txt") -Value $url
        Add-ChatBubble "NOVA: Saved website knowledge source: $url" $false
    }
})
$WorkflowButton.Add_Click({
    $flow = [Microsoft.VisualBasic.Interaction]::InputBox("Describe the workflow NOVA should learn:", "Teach Workflow", "")
    if ($flow) {
        Add-Content -Path (Join-Path $KnowledgeDir "workflows.txt") -Value $flow
        Add-ChatBubble "NOVA: Workflow saved locally." $false
    }
})
$RuleButton.Add_Click({
    $rule = [Microsoft.VisualBasic.Interaction]::InputBox("Add a private rule for NOVA:", "Private Rule", "")
    if ($rule) {
        Add-Content -Path (Join-Path $KnowledgeDir "rules.txt") -Value $rule
        Add-ChatBubble "NOVA: Private rule saved locally." $false
    }
})

$timer = New-Object System.Windows.Threading.DispatcherTimer
$timer.Interval = [TimeSpan]::FromMilliseconds(120)
$timer.Add_Tick({
    $ClockText.Text = (Get-Date).ToString("hh:mm:ss tt")
    Complete-NovaResponseJob
    $script:StatsFrame += 1
    if ($script:StatsFrame -ge 16) {
        $script:StatsFrame = 0
        try {
            $cpu = [Math]::Round((Get-Counter '\Processor(_Total)\% Processor Time').CounterSamples.CookedValue)
            $os = Get-CimInstance Win32_OperatingSystem
            $total = [double]$os.TotalVisibleMemorySize
            $free = [double]$os.FreePhysicalMemory
            $mem = [Math]::Round((($total - $free) / $total) * 100)
            $CpuText.Text = "CPU Engine     $cpu%"
            $CpuBar.Value = $cpu
            $MemText.Text = "Memory         $mem%"
            $MemBar.Value = $mem
        } catch {}
    }
    Render-Waveform
})
$timer.Start()

$Window.Add_Closed({ Stop-NovaMic })
[void]$Window.ShowDialog()
