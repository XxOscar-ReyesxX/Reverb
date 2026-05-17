function app_reverb_ucuenca_final()
    disp('=== Iniciando Reverb UCuenca - Convolución Manual ===');
    
    % ====================== 1. CARGA DE ARCHIVOS ======================
    [arch_x, ruta_x] = uigetfile('*.wav', 'Selecciona señal limpia (x)');
    if isequal(arch_x,0), return; end
    [x, Fs] = audioread(fullfile(ruta_x, arch_x));
    x = mean(x, 2);

    [arch_h, ruta_h] = uigetfile('*.wav', 'Selecciona Respuesta al Impulso (h)');
    if isequal(arch_h,0), return; end
    [h, Fsh] = audioread(fullfile(ruta_h, arch_h));
    h = mean(h, 2);

    if Fs ~= Fsh
        h = resample(h, Fs, Fsh);
    end

    % ==================== RECORTAR IMPULSO (MUY IMPORTANTE) ====================
    duracion_max = 3;   % <-- Puedes cambiar a 4 o 5 segundos máximo
    max_samples = round(duracion_max * Fs);
    if length(h) > max_samples
        h = h(1:max_samples);
        disp(['Impulso recortado a ' num2str(duracion_max) ' segundos']);
    end

    % ====================== CONVOLUCIÓN MANUAL ======================
    disp('Calculando convolución manual...');
    tic;
    y_wet = my_conv_optimized(x, h);
    t = toc;
    disp(['Convolución terminada en ' num2str(t) ' segundos']);

    y_wet = y_wet / max(abs(y_wet));

    len = min(length(x), length(y_wet));
    x = x(1:len);
    y_wet = y_wet(1:len);

    % ====================== INTERFAZ ======================
    fig = uifigure('Name', 'UCUENCA - Reverb', 'Position', [100 100 850 700]);
    
    % (Interfaz resumida)
    ax = uiaxes(fig, 'Position', [70 230 710 330]);
    grid(ax, 'on');
    title(ax, 'Reverberación por Convolución (Manual)');

    sld = uislider(fig, 'Position', [175 140 500 3], 'Limits', [0 100], 'Value', 50);
    uilabel(fig, 'Position', [350 155 150 20], 'Text', 'Nivel de Reverb (%)', 'FontWeight','bold');

    btnPlay = uibutton(fig, 'state', 'Text', 'REPRODUCIR AUDIO', ...
        'Position', [325 50 200 50], 'BackgroundColor', [0.13 0.55 0.13], ...
        'FontColor','w','FontWeight','bold', ...
        'ValueChangedFcn', @(b,e) play_engine(b));

    % ====================== MOTOR DE AUDIO (CORREGIDO) ======================
    function play_engine(btn)
        if ~isvalid(btn) || ~isvalid(fig)   % Protección contra error
            return; 
        end
        
        if btn.Value
            btn.Text = 'DETENER';
            btn.BackgroundColor = [0.75 0.15 0.15];
            
            try
                deviceWriter = audioDeviceWriter('SampleRate', Fs);
                bufferSize = 2048;
                i = 1;

                while i + bufferSize <= len && btn.Value && isvalid(btn)
                    mix = sld.Value / 100;
                    chunk_x   = x(i : min(i+bufferSize-1, len));
                    chunk_wet = y_wet(i : min(i+bufferSize-1, len));
                    chunk_final = (1-mix)*chunk_x + mix*chunk_wet;
                    
                    deviceWriter(chunk_final);

                    if mod(i, bufferSize*6) == 1
                        plot(ax, chunk_x, 'b', 'LineWidth',2); hold(ax,'on');
                        plot(ax, chunk_final, 'r', 'LineWidth',1); hold(ax,'off');
                        legend(ax, 'Señal Limpia', 'Con Reverb');
                        ylim(ax, [-1 1]);
                        drawnow limitrate;
                    end
                    i = i + bufferSize;
                end
            catch
                % Silencioso
            end
            
            % Resetear botón de forma segura
            if isvalid(btn)
                btn.Value = false;
                btn.Text = 'REPRODUCIR AUDIO';
                btn.BackgroundColor = [0.13 0.55 0.13];
            end
            if exist('deviceWriter','var')
                release(deviceWriter);
            end
        end
    end

    % ====================== CONVOLUCIÓN OPTIMIZADA ======================
    function y = my_conv_optimized(x, h)
        x = x(:); h = h(:);
        Lx = length(x);
        Lh = length(h);
        y = zeros(Lx + Lh - 1, 1);
        
        for n = 1:Lx
            k_max = min(Lh, Lx - n + 1);
            y(n : n+k_max-1) = y(n : n+k_max-1) + x(n) * h(1:k_max);
        end
    end
end