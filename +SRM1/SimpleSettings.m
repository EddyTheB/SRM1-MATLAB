classdef SimpleSettings < handle
    % SimpleSettings
    %   A GUI that aks users to specify simple parameters for an SRM1Model,
    %   such as background concentrations and wind speed.
    %
    %   Designed to be raised by SRM1Display.
    %
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % $Workfile:   SimpleSettings.m  $
    % $Revision:   1.0  $
    % $Author:   edward.barratt  $
    % $Date:   Nov 24 2016 11:06:38  $
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties
        Figure
        WindSpeedControl
        BackgroundControls@struct = struct
        ApplyButton
        CancelButton
        Results
    end
    
    properties (SetAccess = 'private', GetAccess = 'private')
        Pollutants = {'O3', 'NOx', 'NO2', 'PM10', 'PM25'}
    end
    
    methods
        function app = SimpleSettings(varargin)
            Options.WindSpeed = 4;
            Options.Backgrounds = struct;
            Options.Backgrounds.O3 = 42;
            Options.Backgrounds.PM10 = 11;
            Options.Backgrounds.PM25 = 7;
            Options.Backgrounds.NO2 = 26;
            Options.Backgrounds.NOx = 41;
            
            app.Results.WindSpeed = -999;
            app.Results.Background.O3 = -999;
            app.Results.Background.PM10 = -999;
            app.Results.Background.PM25 = -999;
            app.Results.Background.NO2 = -999;
            app.Results.Background.NOx = -999;

            NumP = numel(app.Pollutants);
            Height = 30*(NumP+1)+40;
            app.Figure = figure('ToolBar', 'none',  ...
                'MenuBar', 'none', ...
                'Name', 'SRM1 Attributes', ...
                'NumberTitle', 'off', ...
                'Units', 'Pixels', ...
                'Position', [200, 200, 230, Height], ...
                'Visible', 'off', ...
                'CloseRequestFcn', @app.CloseFunction);
            
            YYY = Height - 30;
            
            uicontrol('Style', 'text', ...
                'Parent', app.Figure, ...
                'String', 'Average Wind Speed (m/s)', ...
                'Fontweight', 'bold', ...
                'Position', [5, YYY, 155, 20])
            app.WindSpeedControl = uicontrol('Style', 'edit', ...
                'Parent', app.Figure, ...
                'String', sprintf('%.*f', DecPlaces(Options.WindSpeed), Options.WindSpeed), ...
                'Position', [165, YYY, 60, 20]);
            YYY = YYY - 30;
            
            for Np = 1:NumP
                P = app.Pollutants{Np};
                uicontrol('Style', 'text', ...
                    'Parent', app.Figure, ...
                    'String', sprintf('Background %s (ug/m3)', P), ...
                    'Fontweight', 'bold', ...
                    'Position', [5, YYY, 155, 20])
                app.BackgroundControls.(P) = uicontrol('Style', 'edit', ...
                    'Parent', app.Figure, ...
                    'String', sprintf('%.*f', DecPlaces(Options.Backgrounds.(P)), Options.Backgrounds.(P)), ...
                    'Position', [165, YYY, 60, 20]);
                YYY = YYY - 30;
            end
            
            app.ApplyButton = uicontrol('Style', 'pushbutton', ...
                'Parent', app.Figure, ...
                'String', 'Apply', ...
                'Position', [5, YYY, 110, 20], ...
                'Callback', @app.ApplyFunction);
            app.CancelButton = uicontrol('Style', 'pushbutton', ...
                'Parent', app.Figure, ...
                'String', 'Cancel', ...
                'Position', [120, YYY, 110, 20], ...
                'Callback', @app.CloseFunction);
            
            movegui(app.Figure, 'center')
            set(app.Figure, 'Visible', 'on')
            uicontrol(app.ApplyButton)
        end % function app = SimpleSettings()
        
        function ApplyFunction(app, ~, ~)
            app.Results.WindSpeed = str2double(get(app.WindSpeedControl, 'String'));
            for Np = 1:numel(app.Pollutants)
                P = app.Pollutants{Np};
                app.Results.Background.(P) = str2double(get(app.BackgroundControls.(P), 'String'));
            end
            delete(app.Figure)
        end % function ApplyFunction(app, ~, ~)
        
        function CloseFunction(app, ~, ~)
            delete(app.Figure)
        end % function CloseFunction(app, ~, ~)
    end % methods
    
    methods (Static)
        function Results = RequestValues()
            SS = SRM1.SimpleSettings();
            uiwait(SS.Figure)
            Results = SS.Results;
        end % function RequestValues()
    end % methods (Static)
end % classdef SimpleSettings < handle