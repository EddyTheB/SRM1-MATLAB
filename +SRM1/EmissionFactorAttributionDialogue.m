classdef EmissionFactorAttributionDialogue < handle
    % EmissionFactorAttributionDialogue
    %
    %   A dialogue to allow users to specify the emission factor
    %   attribution. See help EmissionFactorsCat for more datails.
    %
    %   Designed to be raised by SRM1Display.
    %
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % $Workfile:   EmissionFactorAttributionDialogue.m  $
    % $Revision:   1.0  $
    % $Author:   edward.barratt  $
    % $Date:   Nov 25 2016 11:30:52  $
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%

    properties
        Figure
        ModelObject@SRM1Model = SRM1Model.empty
        EmissionFactorCatalogue
        EmissionFactorApportionment
    end % properties
    
    properties (Dependent)
        EmissionFactorName
        CountVehicleBreakdown
        EmissionVehicleBreakdown
        SpeedClasses
        StagnantSpeedClassName
        StagnantSpeedClassNumber
        NumVehicles
    end % properties (Dependent)
    
    properties (Dependent, Hidden)
       EmissionFactorNumber
       EmissionFactorNames
    end % properties (Dependent, Hidden)
    
    properties (Hidden)
        AllPanel
        FigPosition = [100, 100, 265, 590]
        EmissionDropDown
        VehicleEmissionControls
        StagnantSpeedClassControl
        ApplyButton
        ResetButton
        PreferedOrders = {{'Light', 'Medium', 'Heavy', 'Bus'}, ...
            {'PCycle', 'MCycle', 'Car', 'LGV', 'RHGV_2X', 'RHGV_3X', 'RHGV_4X', 'AHGV_34X', 'AHGV_5X', 'AHGV_6X', 'Bus'}}
        SettingsDialogueObject = nan
        EmissionFactorNameP
    end
    
    methods
        %% Constructor
        function app = EmissionFactorAttributionDialogue(varargin)
            Options.ModelObject = 'NotSet';
            Options.Position = app.FigPosition;
            Options.EmissionFactorName = 'NotSet';
            Options.SettingsDialogueObject = 'NotSet';
            Options = checkArguments(Options, varargin);
            if ~isequal(Options.ModelObject, 'NotSet')
                app.ModelObject = Options.ModelObject;
                app.EmissionFactorCatalogue = app.ModelObject.EmissionFactorCatalogue;
                app.EmissionFactorApportionment = app.ModelObject.EmissionFactorApportionment;
            end
            if ~isequal(Options.SettingsDialogueObject, 'NotSet')
                app.SettingsDialogueObject = Options.SettingsDialogueObject;
            end 
            if isequal(Options.EmissionFactorName, 'NotSet')
                app.EmissionFactorNameP = app.ModelObject.EmissionFactorClassName;
            else
                app.EmissionFactorNameP = Options.EmissionFactorName;
            end
            if ismember(numel(Options.Position), [2, 4])
                app.FigPosition(1) = Options.Position(1);
                app.FigPosition(2) = Options.Position(2);
            else
                error('Position should be a 2 value vector.')
            end
            app.EmissionFactorNameP = app.ModelObject.EmissionFactorClassName;
            
            PanelHeight = 30*app.NumVehicles + 95;
            app.FigPosition(4) = PanelHeight+20;
            
            app.Figure = figure('ToolBar', 'none',  ...
                'MenuBar', 'none', ...
                'Name', 'SRM1 Emission Attribution', ...
                'NumberTitle', 'off', ...
                'Units', 'Pixels', ...
                'Position', app.FigPosition, ...
                'Visible', 'off', ...
                'CloseRequestFcn', @app.CloseFunction);
        
            app.AllPanel = uipanel('Parent', app.Figure, ...
                    'Units', 'pixels', ...
                    'Position', [10, 10, 245, PanelHeight]);
            StartY = PanelHeight - 30;
            
            % Emission Factors
            uicontrol('Style', 'text', ...
                'Parent', app.AllPanel, ...
                'String', 'Emission Factors', ...
                'BackgroundColor', [1, 1, 1], ...
                'Position', [10, StartY+5, 110, 15]);
            app.EmissionDropDown = uicontrol('Style', 'popupmenu', ...
                'Parent', app.AllPanel, ...
                'String', app.EmissionFactorNames, ...
                'Value', 1, ...
                'Position', [130, StartY, 100, 20], ...
                'Callback', @app.ChangeValues);
            
            StartY = StartY - 30;
            uicontrol('Style', 'text', ...
                'Parent', app.AllPanel, ...
                'String', 'Stagnant Speed Class', ...
                'BackgroundColor', [1, 1, 1], ...
                'Position', [10, StartY+5, 110, 15]);
            app.StagnantSpeedClassControl = uicontrol('Style', 'popupmenu', ...
                    'Parent', app.AllPanel, ...
                    'String', '------', ...
                    'Value', 1, ... 
                    'Position', [130, StartY+5, 100, 15]);
            
            StartY = StartY - 45;
            
            uicontrol('Style', 'text', ...
                'Parent', app.AllPanel, ...
                'String', 'Vehicle Count Class', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [1, 1, 1], ...
                'Position', [10, StartY, 110, 30]);
            
            uicontrol('Style', 'text', ...
                'Parent', app.AllPanel, ...
                'String', 'Vehicle Emission Class', ...
                'FontWeight', 'bold', ...
                'BackgroundColor', [1, 1, 1], ...
                'Position', [130, StartY, 100, 30]);
            StartY = StartY - 20;
            
            for vi = 1:app.NumVehicles
                Veh = app.CountVehicleBreakdown{vi};
                uicontrol('Style', 'text', ...
                'Parent', app.AllPanel, ...
                'String', Veh, ...
                'BackgroundColor', [1, 1, 1], ...
                'Position', [10, StartY, 110, 15]);
            
                app.VehicleEmissionControls(vi) = uicontrol('Style', 'popupmenu', ...
                    'Parent', app.AllPanel, ...
                    'String', '------', ...
                    'Value', 1, ... 
                    'Position', [130, StartY, 100, 15]);
                StartY = StartY - 25;
            end
            
            StartY = StartY - 10;
            app.ApplyButton = uicontrol('Style', 'pushbutton', ...
                    'Parent', app.AllPanel, ...
                    'String', 'Apply', ...
                    'Position', [10, StartY, 110, 20], ...
                    'Callback', @app.ChangeValues);
            app.ResetButton = uicontrol('Style', 'pushbutton', ...
                    'Parent', app.AllPanel, ...
                    'String', 'Reset', ...
                    'Position', [125, StartY, 110, 20], ...
                    'Callback', @app.ChangeValues);
                
            app.SetValues
            set(app.Figure, 'Visible', 'on')
        end % function app = EmissionFactorAttributionDialogue(varargin)
        
        %% Getters
        function val = get.CountVehicleBreakdown(app)
            val = app.ModelObject.VehicleBreakdown;
        end % function val = get.CountVehicleBreakdown(app)
        
        function val = get.NumVehicles(app)
            val = numel(app.CountVehicleBreakdown);
        end % function val = get.NumVehicles(app)
        
        function val = get.EmissionVehicleBreakdown(app)
            val = app.EmissionFactorCatalogue.FactorCatalogue.(app.EmissionFactorName).VehicleClasses;
            val{end+1} = 'Ignore';
        end % function val = get.EmissionVehicleBreakdown(app)
        
        function val = get.EmissionFactorNames(app)
            val = app.EmissionFactorCatalogue.FactorNames;
        end % function val = get.EmissionFactorNames(app)
        
        function val = get.SpeedClasses(app)
            val = app.EmissionFactorCatalogue.FactorCatalogue.(app.EmissionFactorName).SpeedClasses;
            val{end+1} = 'Ignore';
        end % function val = get.SpeedClasses(app)
        
        function val = get.StagnantSpeedClassName(app)
            val = app.EmissionFactorCatalogue.FactorCatalogue.(app.EmissionFactorName).StagnantSpeedClass;
        end % function val = get.StagnantSpeedClassName(app)
            
        function val = get.StagnantSpeedClassNumber(app)
            [~, val] = ismember(app.StagnantSpeedClassName, app.SpeedClasses);
        end % function val = get.StagnantSpeedClassNumber(app)
              
        function val = get.EmissionFactorNumber(app)
            [~, val] = ismember(app.EmissionFactorName, app.EmissionFactorNames);
        end % function val = get.EmissionFactorName(app)
        
        function val = get.EmissionFactorName(app)
            val = app.EmissionFactorNameP;
        end % function val = get.EmissionFactorName(app)
        
        function set.EmissionFactorName(app, val)
            if ~isequal(val, app.EmissionFactorNameP)
                if ismember(val, app.EmissionFactorNames)
                    app.EmissionFactorNameP = val;
                    app.SetValues
                else
                    error('aaaaa')
                end
            end
        end % function set.EmissionFactorName(app, val)
        
        %% Other functions.
        function SetValues(app)
            set(app.EmissionDropDown, 'Value', app.EmissionFactorNumber)
            set(app.StagnantSpeedClassControl, 'String', app.SpeedClasses, 'Value', app.StagnantSpeedClassNumber)
            for vi = 1:app.NumVehicles
                Veh = app.CountVehicleBreakdown{vi}
                [~, VValue] = ismember('Ignore', app.EmissionVehicleBreakdown);
                for EVBi = 1:numel(app.EmissionVehicleBreakdown)
                    EVeh = app.EmissionVehicleBreakdown{EVBi}
                    try
                        EVehs = app.EmissionFactorApportionment.(app.EmissionFactorName).(EVeh)
                    catch E
                        if ~isequal(E.identifier, 'MATLAB:nonExistentField')
                            disp(E)
                            rethrow(E)
                        else
                            'xxx'
                            continue
                        end
                    end
                    if ismember(Veh, EVehs)
                        VValue = EVBi
                        break
                    end
                end
                VValue
                set(app.VehicleEmissionControls(vi), 'string', app.EmissionVehicleBreakdown, 'value', VValue)
            end
        end % function SetValues(app)
            
        function EFA = GetApportionment(app)
            EFA = struct;
            for EVBi = 1:numel(app.EmissionVehicleBreakdown)
                EVeh = app.EmissionVehicleBreakdown{EVBi};
                EFA.(EVeh) = {};
            end
            for vi = 1:app.NumVehicles
                Veh = app.CountVehicleBreakdown{vi};
                EFA.(app.EmissionVehicleBreakdown{get(app.VehicleEmissionControls(vi), 'Value')}){end+1} = Veh;
            end
            for EVBi = 1:numel(app.EmissionVehicleBreakdown)
                EVeh = app.EmissionVehicleBreakdown{EVBi};
                if ~numel(EFA.(EVeh))
                    EFA = rmfield(EFA, EVeh);
                end 
            end
            if ismember('Ignore', fieldnames(EFA))
                EFA = rmfield(EFA, 'Ignore');
            end
        end
        
        function [EFA_New, SameAP, SSC_New, SameSSC] = CheckChanges(app)
            EFA_New = app.GetApportionment
            EFA_Old = app.EmissionFactorApportionment.(app.EmissionFactorName)
            SameAP = isequal(EFA_New, EFA_Old);
            SSC_New = app.SpeedClasses{get(app.StagnantSpeedClassControl, 'Value')};
            SSC_Old = app.EmissionFactorCatalogue.FactorCatalogue.(app.EmissionFactorName).StagnantSpeedClass;
            SameSSC = isequal(SSC_New, SSC_Old);
        end % function [EFA_New, SameAP, SSC_New, SameSSC] = CheckChanges(app)
        
        function ChangeValues(app, Sender, ~)
            set(app.Figure, 'Pointer', 'watch'); 
            set([app.ResetButton, app.ApplyButton], 'Enable', 'off');
            pause(0.01)
            [EFA_New, SameAP, SSC_New, SameSSC] = CheckChanges(app);
            switch Sender
                case app.ApplyButton
                    if ~SameAP
                        app.ModelObject.EmissionFactorApportionment.(app.EmissionFactorName) = EFA_New;
                        %app.EmissionFactorApportionment.(app.EmissionFactorName) = EFA_New;
                    end
                    if ~SameSSC
                        app.ModelObject.StagnantSpeedClass = SSC_New;
                        %app.EmissionFactorCatalogue.FactorCatalogue.(app.EmissionFactorName).StagnantSpeedClass = SSC_New;
                    end
                    app.SetValues
                case app.ResetButton
                    app.SetValues
                case app.EmissionDropDown
                    % Check that no values have been changed.
                    if ~SameAP
                        msgbox(sprintf('Emission factor apportionment for %s has been changed, either apply those changes or reset them.', app.EmissionFactorName))
                        set(app.EmissionDropDown, 'Value', app.EmissionFactorNumber)
                    elseif ~SameSSC
                        msgbox(sprintf('Emission factor stagnant speed class for %s has been changed, either apply those changes or reset them.', app.EmissionFactorName))
                        set(app.EmissionDropDown, 'Value', app.EmissionFactorNumber)
                    else
                        app.EmissionFactorName = app.EmissionFactorNames{get(Sender, 'Value')};
                        app.SetValues
                    end
                otherwise
                    error('EmissionFactorAttributionDialogue:ChangeValue:UnknownSender', 'Unknown sender for ChangeValue function')
            end
            set([app.ResetButton, app.ApplyButton], 'Enable', 'on');
            set(app.Figure, 'Pointer', 'arrow')
        end % function ChangeValues(app, Sender ~)
        
        function CloseFunction(app, ~, ~)
            [~, SameAP, ~, SameSSC] = CheckChanges(app);
            if ~SameAP
                msgbox(sprintf('Emission factor apportionment for %s has been changed, either apply those changes or reset them.', app.EmissionFactorName))
                set(app.EmissionDropDown, 'Value', app.EmissionFactorNumber)
            elseif ~SameSSC
                msgbox(sprintf('Emission factor stagnant speed class for %s has been changed, either apply those changes or reset them.', app.EmissionFactorName))
                set(app.EmissionDropDown, 'Value', app.EmissionFactorNumber)
            else
                if isa(app.SettingsDialogueObject, 'SRM1.SettingsDialogue')
                    app.SettingsDialogueObject.EmissionAttributionWindowPosition = get(app.Figure, 'Position');
                end
                delete(app.Figure)
            end            
        end % function CloseFunction(app, ~, ~)
    end % methods
end % classdef SettingsDialogue < handle