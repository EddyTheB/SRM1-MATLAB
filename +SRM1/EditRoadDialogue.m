classdef EditRoadDialogue < handle
    % EditRoadDialogue
    %
    %   A dialogue to allow users to control properties of individual
    %   SRM1.RoadSegment objects, in particular the scaling of vehicles.
    %
    %   Designed to be raised by SRM1Display.
    %
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % $Workfile:   EditRoadDialogue.m  $
    % $Revision:   1.0  $
    % $Author:   edward.barratt  $
    % $Date:   Nov 25 2016 11:30:52  $
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties
        DisplayObject@SRM1Display = SRM1Display.empty
        RoadNetwork = SRM1.RoadNetwork.empty
    end % properties
    
    properties (Dependent)
        Figure
        FigTag
        RoadSegment
        RoadSegmentIndex
        RoadSegmentIndices
        VehicleBreakdown
        NumRoads
    end % properties (Dependent)
    
    properties (SetAccess = private)
        Position
    end % properties (SetAccess = private)
    
    properties (GetAccess = private, SetAccess = private)
        RoadSegmentP@SRM1.RoadSegment
        RoadSegmentIndexP = 1
        RoadSegmentIndicesP
        
        TitleText
        PrevButton
        NextButton
        WarningString
        RoadIDText
        RoadNameText
        StreetParameterPanel
        RoadSegmentPanel
        VehicleScalingPanel
        ConcentrationPanel
        RoadClassDropDown
        RoadClassString = {'Narrow Canyon', 'One Sided Canyon', 'Wide Canyon', 'Not A Canyon'};
        TreeFactorDropDown
        TreeFactorString = {'1: No Tree Effect', '1.25: Small Tree Effect', '1.5: Large Tree Effect'};
        SpeedClassDropDown
        SpeedClassString
        StagnationSlider
        StagnationText
        StagnationEdit
        SpeedDropDown
        ApplyButton
        CancelButton
        SpeedString
        VScaleEdit
        VScaleSlider
        VCountText
        VEmitText
        VCountEdit
        VEditCheckBox
        DistanceText
        TCText
        BCText
        ToTText
        RedText
        ScaleMax = 2
        Constructing
        VPanelPos
        RoadPPos
        FigHeight
    end % properties (SetAccess = private)
    
    methods
        function app = EditRoadDialogue(varargin)
            app.Constructing = 1;
            Options.DisplayObject = 'None';
            Options.RoadSegment = 'None';
            Options.Position = [100, 100];
            Options = checkArguments(Options, varargin);
            % Has a DisplayObject been specified?
            if ~isequal(Options.DisplayObject, 'None')
                % It has. Set the road network to be the network for the
                % display.
                app.DisplayObject = Options.DisplayObject;
                app.RoadNetwork = Options.DisplayObject.Model.RoadNetwork;
            else
                error('SRM1:EditRoadDialogue:NoDisplayObject', 'A DisplayObject must be specified.')
            end
            % Has a road segment been specifeid?
            if isequal(Options.RoadSegment, 'None')
                % No road segment has been designated. Assume it's the
                % first one.
                app.RoadSegmentIndices = 1;
                app.RoadSegmentIndex = 1;
            elseif isequal(Options.RoadSegment, 'All')
                % All specified.
                app.RoadSegmentIndices = 1:app.RoadNetwork.NumRoads;
                app.RoadSegmentIndex = 1;
            else
                % One or many individual segments specified.
                app.RoadSegmentIndices = Options.RoadSegment;
                app.RoadSegmentIndex = app.RoadSegmentIndices(1);
            end
            app.RoadNetwork.RoadSegments(1).TrafficContributionsNO2
            % Create the GUI
            if numel(Options.Position) == 2
                Options.Position = [Options.Position, 460, 520];
            elseif numel(Options.Position) ~= 4
                error('Position should be 2 or 4 element.')
            end
            app.Position = Options.Position;
            
            % Some layout values.
            ApplyHeight = 10;
            ConcentrationHeightA = ApplyHeight+30;
            VehiclesHeightA = ConcentrationHeightA+80;
            VehiclesHeightB = ConcentrationHeightA;
            NumVs = numel(app.VehicleBreakdown);
            VPanelHeight = NumVs * 20 + 50;
            app.VPanelPos.A = [10, VehiclesHeightA, 440, VPanelHeight];
            app.VPanelPos.B = [10, VehiclesHeightB, 440, VPanelHeight];
            StreetPHeightA = VehiclesHeightA + VPanelHeight + 10;
            RoadPHeightA = StreetPHeightA + 90;
            app.RoadPPos.A = [10, RoadPHeightA, 440, 30];
            RoadPHeightB = VehiclesHeightB + VPanelHeight + 10;
            app.RoadPPos.B = [10, RoadPHeightB, 440, 30];
            app.FigHeight.A = RoadPHeightA + 40;
            app.FigHeight.B = RoadPHeightB + 40;
            
            app.Position(4) = app.FigHeight.A;
            
            % To avoid conflicts, all EditRoadDialogues will be assigned a
            % number between 99800 and 99899.
            fNum = 99800;
            while ishghandle(fNum)
                fNum = fNum + 1;
                if fNum > 99899
                    error('SRM1:EditRoadDialogue:fNumTooLarge', 'No available figure numbers left.')
                end
            end
            
            figure('Position', app.Position, ...
                'handleVisibility', 'off', ...
                'Visible', 'on', ...
                'MenuBar', 'none', ...
                'ToolBar', 'none',  ...
                'Name', 'Edit properties of road section', ...
                'NumberTitle', 'off', ...
                'Tag', app.FigTag, ...
                'Pointer', 'watch', ...
                'CloseRequestFcn', @app.CloseFunction);
            % Road Segment panel
            app.RoadSegmentPanel = uipanel('Parent', app.Figure, ...
                                           'Units', 'pixels', ...
                                           'Position', app.RoadPPos.A, ...
                                           'BackgroundColor', [0.8, 0.8, 0.8]);
            app.PrevButton = uicontrol('Style', 'pushbutton', ...
                'Parent', app.RoadSegmentPanel, ...
                'String', 'Previous', ...
                'Position', [5, 5, 60, 20], ...
                'Callback', @app.PrevRoad);
            app.TitleText = uicontrol('Style', 'text', ...
                'Parent', app.RoadSegmentPanel, ...
                'String', '-----', ...
                'FontWeight', 'bold', ...
                'Position', [70, 5, 300, 20]);
            app.NextButton = uicontrol('Style', 'pushbutton', ...
                'Parent', app.RoadSegmentPanel, ...
                'String', 'Next', ...
                'Position', [375, 5, 60, 20], ...
                'Callback', @app.NextRoad);
            
            % Street parameter panel. Will only be visible if the number of
            % roads selected is exactly one.
            app.StreetParameterPanel = uipanel('Parent', app.Figure, ...
                                           'Units', 'pixels', ...
                                           'Position', [10, StreetPHeightA, 440, 80], ...
                                           'BackgroundColor', [0.8, 0.8, 0.8]);
            % Road ID
            uicontrol('Style', 'text', ...
                'Parent', app.StreetParameterPanel, ...
                'String', 'Road ID', ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left', ...
                'Position', [5, 55, 75, 15])
            app.RoadIDText = uicontrol('Style', 'text', ...
                'Parent', app.StreetParameterPanel, ...
                'String', '---', ...
                'HorizontalAlignment', 'left', ...
                'Position', [85, 55, 130, 15]);
            % Road Name
            uicontrol('Style', 'text', ...
                'Parent', app.StreetParameterPanel, ...
                'String', 'Road Name', ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left', ...
                'Position', [5, 30, 75, 15])
            app.RoadNameText = uicontrol('Style', 'text', ...
                'Parent', app.StreetParameterPanel, ...
                'String', '---', ...
                'HorizontalAlignment', 'left', ...
                'Position', [85, 30, 130, 15]);
            % Road Class
            uicontrol('Style', 'text', ...
                'Parent', app.StreetParameterPanel, ...
                'String', 'Road Class', ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left', ...
                'Position', [5, 5, 75, 15])
            app.RoadClassDropDown = uicontrol('Style','popupmenu', ...
                'Parent', app.StreetParameterPanel, ...
                'String', app.RoadClassString, ...
                'Value', 1, ...
                'Position', [85, 5 ,130, 20]);
            % Tree Factor
            uicontrol('Style', 'text', ...
                'Parent', app.StreetParameterPanel, ...
                'String', 'Tree Factor', ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left', ...
                'Position', [225, 55, 75, 15])
            app.TreeFactorDropDown = uicontrol('Style','popupmenu', ...
                'Parent', app.StreetParameterPanel, ...
                'String', app.TreeFactorString, ...
                'Value', 1, ...
                'Position',[305, 55, 130, 20]);
            %Speed
            uicontrol('Style', 'text', ...
                'Parent', app.StreetParameterPanel, ...
                'String', 'Speed Class', ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left', ...
                'Position', [225, 30, 75, 15]);
            app.SpeedClassDropDown = uicontrol('Style','popupmenu', ...
                'Parent', app.StreetParameterPanel, ...
                'String', '-----', ...
                'Value', 1, ...
                'Position',[305, 30, 130, 20]);
            
            app.StagnationText = uicontrol('Style', 'text', ...
                'Parent', app.StreetParameterPanel, ...
                'String', 'Stagnation Factor', ...
                'FontWeight', 'bold', ...
                'HorizontalAlignment', 'left', ...
                'Position', [225, 5, 75, 15]);
            app.StagnationEdit = uicontrol('Style','edit', ...
                'Parent', app.StreetParameterPanel, ...
                'String', '----', ...
                'Position',[305, 5, 45, 15], ...
                'Callback', @app.SetStagnationEdit);
            app.StagnationSlider = uicontrol('Style','slider', ...
                'Parent', app.StreetParameterPanel, ...
                'Min', 0, 'Max', 1, ...
                'Value', 0, ...
                'Position',[360, 5, 75, 15], ...
                'Callback', @app.SetStagnationSlider);    
            
            % Vehicle parameter panel.            
            app.VehicleScalingPanel = uipanel('Parent', app.Figure, ...
                                           'Units', 'pixels', ...
                                           'Position', app.VPanelPos.A, ...
                                           'BackgroundColor', [0.8, 0.8, 0.8]);
            TT = VPanelHeight - 35;
            % For each vehicle class...
            uicontrol('Style', 'text', ...
                    'Parent', app.VehicleScalingPanel, ...
                    'String', 'Vehicle Class', ...
                    'FontWeight', 'bold', ...
                    'Position', [5, TT, 85, 30])
            uicontrol('Style', 'text', ...
                    'Parent', app.VehicleScalingPanel, ...
                    'String', 'Original Count', ...
                    'FontWeight', 'bold', ...
                    'Position', [95, TT, 60, 30])
            uicontrol('Style', 'text', ...
                    'Parent', app.VehicleScalingPanel, ...
                    'String', 'Scaling', ...
                    'FontWeight', 'bold', ...
                    'Position', [160, TT, 100, 30])
            uicontrol('Style', 'text', ...
                    'Parent', app.VehicleScalingPanel, ...
                    'String', 'Calculation Count', ...
                    'FontWeight', 'bold', ...
                    'Position', [265, TT, 65, 30])
            uicontrol('Style', 'text', ...
                    'Parent', app.VehicleScalingPanel, ...
                    'String', 'Emissions %', ...
                    'FontWeight', 'bold', ...
                    'Position', [335, TT, 65, 30])
            uicontrol('Style', 'text', ...
                    'Parent', app.VehicleScalingPanel, ...
                    'String', 'Edit', ...
                    'FontWeight', 'bold', ...
                    'Position', [405, TT, 30, 30])
            TT = TT - 25;
            app.VScaleEdit = nan(1, NumVs);
            app.VScaleSlider = [];
            app.VCountEdit = nan(1, NumVs);
            app.VEditCheckBox = nan(1, NumVs);
            for VI = 1:NumVs
                if VI == NumVs+1
                    V = 'All';
                    B = 'bold';
                else
                    V = app.VehicleBreakdown{VI};
                    B = 'normal';
                end
                uicontrol('Style', 'text', ...
                    'Parent', app.VehicleScalingPanel, ...
                    'String', V, ...
                    'FontWeight', B, ...
                    'Position', [5, TT, 85, 15])
                app.VCountText(VI) = uicontrol('Style', 'text', ...
                    'Parent', app.VehicleScalingPanel, ...
                    'String', '---', ...
                    'FontWeight', B, ...
                    'Position', [95, TT, 60, 15]);
                app.VScaleEdit(VI) = uicontrol('Style', 'edit', ...
                    'Parent', app.VehicleScalingPanel, ...
                    'String', '---', ...
                    'FontWeight', B, ...
                    'Position', [160, TT, 35, 15], ...
                    'Callback', @app.EditVScaleEdit);
                app.VScaleSlider(VI) = uicontrol('Style', 'slider', ...
                    'Parent', app.VehicleScalingPanel, ...
                    'Value', 1, ...
                    'Min', 0, 'Max', app.ScaleMax, ...
                    'Position', [200, TT, 60, 15], ...
                    'Callback', @app.EditVScaleSlider);
                app.VCountEdit(VI) = uicontrol('Style', 'edit', ...
                    'Parent', app.VehicleScalingPanel, ...
                    'String', '---', ...
                    'FontWeight', B, ...
                    'Position', [265, TT, 65, 15], ...
                    'Callback', @app.EditVCountEdit);
                app.VEmitText(VI) = uicontrol('Style', 'text', ...
                    'Parent', app.VehicleScalingPanel, ...
                    'String', '---', ...
                    'FontWeight', B, ...
                    'Position', [335, TT, 65, 15]);
                app.VEditCheckBox(VI) = uicontrol('Style', 'CheckBox', ...
                    'Parent', app.VehicleScalingPanel, ...
                    'Value', 0, ...
                    'Position', [413, TT, 15, 15], ...
                    'Callback', @app.EditVCountEdit);
                TT = TT - 20;
            end
            app.ConcentrationPanel = uipanel('Parent', app.Figure, ...
                                    'Units', 'pixels', ...
                                    'Position', [10, ConcentrationHeightA, 440, 70], ...
                                    'BackgroundColor', [0.8, 0.8, 0.8]);
            app.DistanceText = uicontrol('Style', 'text', ...
                      'Parent', app.ConcentrationPanel, ...
                      'String', 'Traffic contribution at --- m', ...
                      'HorizontalAlignment', 'right', ...
                      'Position', [5, 45, 150, 15]);
            app.TCText = uicontrol('Style', 'text', ...
                      'Parent', app.ConcentrationPanel, ...
                      'String', '---', ...
                      'Position', [160, 45, 65, 15]);
            uicontrol('Style', 'text', ...
                      'Parent', app.ConcentrationPanel, ...
                      'String', 'Background Concentration', ...
                      'HorizontalAlignment', 'right', ...
                      'Position', [5, 25, 150, 15]);
            app.BCText = uicontrol('Style', 'text', ...
                      'Parent', app.ConcentrationPanel, ...
                      'String', '---', ...
                      'Position', [160, 25, 65, 15]);
            uicontrol('Style', 'text', ...
                      'Parent', app.ConcentrationPanel, ...
                      'String', 'Total', ...
                      'HorizontalAlignment', 'right', ...
                      'Position', [5, 5, 150, 15]);
            app.ToTText = uicontrol('Style', 'text', ...
                      'Parent', app.ConcentrationPanel, ...
                      'String', '---', ...
                      'Position', [160, 5, 65, 15]);
            app.RedText = uicontrol('Style', 'text', ...
                      'Parent', app.ConcentrationPanel, ...
                      'String', '---', ...
                      'Position', [230, 5, 200, 55]);
                                
            % Apply, Cancel
            app.ApplyButton = uicontrol('Style', 'pushbutton', ...
                'String', 'Apply', ...
                'Position', [310, ApplyHeight, 65, 20], ...
                'Callback', @app.Apply);
            app.CancelButton = uicontrol('Style', 'pushbutton', ...
                'String', 'Cancel', ...
                'Position', [385, ApplyHeight, 65, 20], ...
                'Callback', @app.Cancel);
            app.Constructing = 0;
            app.SetValues
            set(app.Figure, 'Visible', 'on', 'Pointer', 'arrow')
        end % function app = EditRoadDialogue(varargin)
            
        %% Getters
        function val = get.FigTag(app)
            val = sprintf('%s_ROAD', app.DisplayObject.Instance);
        end % function val = get.FigTag(app)
        
        function val = get.RoadSegment(app)
            val = app.RoadNetwork.RoadSegments(app.RoadSegmentIndex);
        end % function val = get.RoadSegment(app)
        
        function val = get.RoadSegmentIndex(app)
            val = app.RoadSegmentIndexP;
        end % function val = get.RoadSegmentIndex(app)
        
        function val = get.RoadSegmentIndices(app)
            val = app.RoadSegmentIndicesP;
        end % function val = get.RoadSegmentIndices(app)
        
        function val = get.NumRoads(app)
            val = numel(app.RoadSegmentIndices);
        end % function val = get.NumRoads(app)
        
        function val = get.VehicleBreakdown(app)
            val = app.RoadSegment.VehicleBreakdown;
        end % function val = get.VehicleBreakdown(app)
        
        %% Setters
        function set.RoadSegmentIndex(app, val)
            if ~isequal(app.RoadSegmentIndexP, val)
                app.RoadSegmentIndexP = val;
                if ~app.Constructing
                    app.SetValues
                end
            end
        end % function val = get.RoadSegmentIndex(app)
        
        function set.RoadSegmentIndices(app, val)
            if ~isequal(app.RoadSegmentIndicesP, val)
                if isequal(val, 'All')
                    app.RoadSegmentIndicesP = 1:app.RoadNetwork.NumRoads;
                elseif isa(val, 'SRM1.RoadSegment')
                    RSI = [];
                    for RS = val
                        [IsM, RSI_] = ismember(RS, app.RoadNetwork.RoadSegments);
                        if IsM
                            RSI(end+1) = RSI_; %#ok<AGROW>
                        else
                            error('SRM1:EditRoadDialogue:Constructor:WrongRoadSegment', 'Atleast one of the specified road segments is not a member of the specified road network.')
                        end
                    end
                    app.RoadSegmentIndicesP = RSI;
                    app.RoadSegmentIndexP = RSI(1);
                else
                    app.RoadSegmentIndicesP = val;
                    app.RoadSegmentIndexP = val(1);
                end
                if ~app.Constructing
                    app.SetValues
                end
                if numel(app.RoadSegmentIndicesP) ~= app.RoadNetwork.NumRoads
                    app.DisplayObject.SelectedRoad = app.RoadSegmentIndicesP;
                end
            end
        end % function val = get.RoadSegmentIndices(app)
        
        %% Other Functions
        function EditVCountEdit(app, Sender, ~)
            [Is, VI] = ismember(Sender, app.VCountEdit);
            if Is
                %V = app.RoadSegment.VehicleBreakdown{VI};
                CountValue = str2double(get(app.VCountText(VI), 'String'));
                %app.RoadSegment.VehicleCounts.(V);
                SetValue = str2double(get(Sender, 'String'));
                NewScaling = SetValue/CountValue;
                set(app.VScaleEdit(VI), 'String', sprintf('%.2f', NewScaling))
                if NewScaling > app.ScaleMax
                    app.ScaleMax = ceil(NewScaling);
                    set(app.VScaleSlider, 'Max', app.ScaleMax)
                end
                set(app.VScaleSlider(VI), 'Value', NewScaling)
                set(app.VEditCheckBox(VI), 'value', 1)
            end
        end % function EditVCountEdit(app, ~, ~)
        
        function EditVScaleEdit(app, Sender, ~)
            [Is, VI] = ismember(Sender, app.VScaleEdit);
            if Is
                %V = app.RoadSegment.VehicleBreakdown{VI};
                CountValue = str2double(get(app.VCountText(VI), 'String'));
                %app.RoadSegment.VehicleCounts.(V);
                SetValue = str2double(get(Sender, 'String'));
                NewCount = CountValue*SetValue;
                set(app.VCountEdit(VI), 'String', sprintf('%.0f', NewCount))
                if SetValue > app.ScaleMax
                    app.ScaleMax = ceil(SetValue);
                    set(app.VScaleSlider, 'Max', app.ScaleMax)
                end
                set(app.VScaleSlider(VI), 'Value', SetValue)
                set(app.VEditCheckBox(VI), 'value', 1)
            end
        end % function EditVScaleEdit(app, ~, ~)
        
        function EditVScaleSlider(app, Sender, ~)
            [Is, VI] = ismember(Sender, app.VScaleSlider);
            if Is
                CountValue = str2double(get(app.VCountText(VI), 'String'));
                SetValue = get(Sender, 'Value');
                NewCount = CountValue*SetValue;
                set(app.VCountEdit(VI), 'String', sprintf('%.1f', NewCount))
                set(app.VScaleEdit(VI), 'String', sprintf('%.2f', SetValue))
                set(app.VEditCheckBox(VI), 'value', 1)
            end
        end % function EditVScaleSlider(app, ~, ~)
        
        function SetStagnationEdit(app, Sender, ~)
            StagnationValue = str2double(get(Sender, 'String'));
            if StagnationValue < 0
                StagnationValue = 0;
                set(app.StagnationEdit, 'String', '0')
            elseif StagnationValue > 1
                StagnationValue = 1;
                set(app.StagnationEdit, 'String', '1')
            end
            set(app.StagnationSlider, 'Value', StagnationValue)
        end % function SetStagnationEdit(app, Sender, ~)
            
        function SetStagnationSlider(app, Sender, ~)
            StagnationValue = get(Sender, 'Value');
            set(app.StagnationEdit, 'String', sprintf('%5.3f', StagnationValue))
        end % function SetStagnationSlider(app, Sender, ~)
        
        function SetValues(app)
            Pollutant = app.DisplayObject.Pollutant;
            app.Position = get(app.Figure, 'Position');
            % Now organise the layout based on the particular circumstances.
            % How many selected roads are there?
            if app.NumRoads == 1
                % Single Road.
                % Layout
                set([app.ConcentrationPanel, app.PrevButton, app.NextButton, app.StreetParameterPanel], 'Visible', 'on')
                set(app.VehicleScalingPanel, 'Position', app.VPanelPos.A);
                set(app.RoadSegmentPanel, 'Position', app.RoadPPos.A);
                app.Position(4) = app.FigHeight.A;
                set(app.Figure, 'Position', app.Position)
                
                % Title
                set(app.TitleText, 'String', sprintf('Road %d of %d', app.RoadSegmentIndex, app.RoadNetwork.NumRoads))
                % Road details
                set(app.RoadIDText, 'String', app.RoadSegment.RoadID)
                set(app.RoadNameText, 'String', app.RoadSegment.RoadName)
                % Road Class
                [~, RCI] = ismember(app.RoadSegment.RoadClass, app.RoadClassString);
                set(app.RoadClassDropDown, 'Value', RCI)
                % Tree Factor
                switch app.RoadSegment.TreeFactor
                    case 1
                        set(app.TreeFactorDropDown, 'Value', 1)
                    case 1.25
                        set(app.TreeFactorDropDown, 'Value', 2)
                    case 1.5
                        set(app.TreeFactorDropDown, 'Value', 3)
                    otherwise
                        error('EditRoadDialogue:SetValuies:TreeFactor', 'Tree Factor should be 1, 1.25 or 1.5')
                end
                % Speed Class
                app.SpeedClassString = app.RoadSegment.EmissionFactors.SpeedClasses;
                [~, SCI] = ismember(app.RoadSegment.SpeedClassCorrect, app.SpeedClassString);
                set(app.SpeedClassDropDown, 'String', app.SpeedClassString, 'Value', SCI)
                
                if isequal(app.RoadNetwork.EmissionFactors.StagnantSpeedClass, 'Ignore')
                    StagnantColor = 'red';
                    StagnantMouseOverText = 'Stagnation factor is ignored for current emission factors';
                else
                    StagnantColor = 'black';
                    StagnantMouseOverText = sprintf('%5.1f%% of vehicles will be assigned a speed class of %s', app.RoadSegment.Stagnation*100, app.RoadNetwork.EmissionFactors.StagnantSpeedClass);
                end
                set(app.StagnationEdit, 'String', sprintf('%5.3f', app.RoadSegment.Stagnation), ...
                    'ForegroundColor', StagnantColor, ...
                    'TooltipString', StagnantMouseOverText)
                set(app.StagnationSlider, 'Value', app.RoadSegment.Stagnation, 'TooltipString', StagnantMouseOverText)
                          
                % Concentrations.
                BGString = ['RoadBackground', Pollutant];
                TCValue = app.RoadSegment.TrafficContributions.(Pollutant);
                try
                    BGValue = app.DisplayObject.Model.(BGString)(app.RoadSegmentIndex);
                catch err
                    disp(err)
                    rethrow(err)
                    % Possible issue if background is one value.
                end
                ToTValue = BGValue + TCValue;
                Limit = app.DisplayObject.Limit;
                Dist = app.RoadSegment.CalculationDistance;
                set(app.DistanceText, 'String', sprintf('Traffic contribution at %.*f m', DecPlaces(Dist), Dist))
                MessageType = 1;
                if BGValue > Limit
                    set(app.BCText, 'String', sprintf('%.1f', BGValue), 'ForegroundColor', 'red')
                    MessageType = 2;
                else
                    set(app.BCText, 'String', sprintf('%.1f', BGValue), 'ForegroundColor', 'black')
                end
                if TCValue > Limit
                    set(app.TCText, 'String', sprintf('%.1f', TCValue), 'ForegroundColor', 'red')
                else
                    set(app.TCText, 'String', sprintf('%.1f', TCValue), 'ForegroundColor', 'black')
                end
                if ToTValue > Limit
                    set(app.ToTText, 'String', sprintf('%.1f', ToTValue), 'ForegroundColor', 'red')
                    MessageType = 3;
                else
                    set(app.ToTText, 'String', sprintf('%.1f', ToTValue), 'ForegroundColor', 'black')
                end
                if MessageType == 1
                    set(app.RedText, 'String', sprintf('Meeting specified standard of %.*f ugm-3 at %.*f metres from road centre.', DecPlaces(Limit), Limit, DecPlaces(Dist), Dist), 'ForegroundColor', 'black')
                elseif MessageType == 2
                    set(app.RedText, 'String', 'Specified standard cannot be met without reductions in background concentration.', 'ForegroundColor', 'red')
                elseif MessageType == 3
                    HeadRoom = Limit - BGValue;
                    Over = TCValue - HeadRoom;
                    PercentageOver = ceil(100*Over/TCValue);
                    set(app.RedText, 'String', sprintf('Reduce traffic emissions by %d percent to meet specified standard of %.*f ugm-3 at %.*f metres from %s.', PercentageOver, DecPlaces(Limit), Limit, DecPlaces(Dist), Dist, lower(app.DisplayObject.CalculationDistanceMode)), 'ForegroundColor', 'red')
                else
                    error('Ehhh')
                end
            
            else
                % Multiple Roads
                % Layout
                set([app.ConcentrationPanel, app.PrevButton, app.NextButton, app.StreetParameterPanel], 'Visible', 'off')
                set(app.VehicleScalingPanel, 'Position', app.VPanelPos.B);
                set(app.RoadSegmentPanel, 'Position', app.RoadPPos.B);
                app.Position(4) = app.FigHeight.B;
                set(app.Figure, 'Position', app.Position)
                
                % Title
                set(app.TitleText, 'String', sprintf('Edit scaling for %d of %d roads', app.NumRoads, app.RoadNetwork.NumRoads))
                if app.NumRoads == app.RoadNetwork.NumRoads
                    app.WarningString = ['Scaling is not identical across all roads. If you', ...
                        ' adjust the scaling using this dialogue, then you', ...
                        ' will be adjusting scaling for all roads.'];
                else
                    app.WarningString = ['Scaling is not identical across all selected roads. If you', ...
                        ' adjust the scaling using this dialogue, then you', ...
                        ' will be adjusting scaling for all selected roads.'];
                end
            end
            
            % Vehicle Counts
            NumVs = numel(app.VehicleBreakdown);
            IncludedVehs = {};
            % Get the vehicle apportionment details.
            EFA = app.DisplayObject.Model.EmissionFactorApportionment.(app.DisplayObject.Model.EmissionFactorClassName);
            EFAFNames = fieldnames(EFA);
            for EFAFNamesI = 1:numel(EFAFNames)
                EFAFName = EFAFNames{EFAFNamesI};
                Include = EFA.(EFAFName);
                IncludedVehs(end+1:end+numel(Include)) = Include;
            end
            % Get the values for each vehicle.
            Tot = NumVs*numel(app.RoadSegmentIndices);
            Iii = 0;
            wb = waitbar(0, sprintf('Assessing vehicle counts for selected roads.'), 'Visible', 'off');
            if numel(app.RoadSegmentIndices) > 3
                set(wb, 'Visible', 'on')
            end
            setappdata(wb, 'canceling', 0)
            for VI = 1:NumVs
                V = app.VehicleBreakdown{VI};
                if app.NumRoads ~= 1
                    % More than one road.
                    % For each vehicle, counts will be total across all
                    % streets.
                    % Scaling will be average across all streets.
                    VC = 0; RL = 0;
                    VS = nan(1, app.NumRoads);
                    for RI = app.RoadSegmentIndices
                        Iii = Iii + 1;
                        waitbar(Iii/Tot, wb)
                        RL = RL + 1;
                        RS = app.RoadNetwork.RoadSegments(RI);
                        VC = VC + RS.VehicleCounts.(V);
                        if RL == 1
                            EBDs = RS.EmissionsBreakdown.(Pollutant);
                            E = RS.Emissions.(Pollutant);
                        else
                            EBDs = EBDs + RS.EmissionsBreakdown.(Pollutant);
                            E = E + RS.Emissions.(Pollutant);
                        end
                        VS(RL) = RS.VehicleScaling.(V);
                    end
                    if numel(unique(VS)) == 1
                        AllSame = 1;
                    else
                        AllSame = 0;
                    end
                    VS = mean(VS);
                else
                    % Only one road.    
                    EBDs = app.RoadSegment.EmissionsBreakdown.(Pollutant);
                    E = app.RoadSegment.Emissions.(Pollutant);
                    VC = app.RoadSegment.VehicleCounts.(V);
                    VS = app.RoadSegment.VehicleScaling.(V);
                    AllSame = 1;
                end
                if VS > app.ScaleMax
                    app.ScaleMax = ceil(VS);
                    set(app.VScaleSlider, 'Max', app.ScaleMax)
                end
                EBD = EBDs(VI);
                EP = 100*EBD/E;
                set(app.VCountText(VI), 'String', sprintf('%.2f', VC))
                set(app.VScaleEdit(VI), 'String', sprintf('%.1f', VS))
                set(app.VScaleSlider(VI), 'Value', VS, ...
                        'Min', 0, 'Max', app.ScaleMax);
                set(app.VCountEdit(VI), 'String', sprintf('%.2f', VC*VS));
                if ismember(V, IncludedVehs)
                    VehEmitColor = 'black';
                    VehEmitMouseOver = sprintf('%ss contribute %.1f%% of the traffic emissions.', V, EP);
                else
                    VehEmitColor = 'red';
                    VehEmitMouseOver = sprintf('%ss are ignored by the specified emission factors.', V);
                end
                set(app.VEmitText(VI), 'String', sprintf('%.1f', EP), ...
                                       'ForegroundColor', VehEmitColor, ...
                                       'TooltipString', VehEmitMouseOver)
                if AllSame
                    set(app.VScaleEdit(VI), 'ForegroundColor', 'k', 'TooltipString', '')
                    set(app.VCountEdit(VI), 'ForegroundColor', 'k', 'TooltipString', '')
                    set(app.VEditCheckBox(VI), 'Value', 1)
                else
                    set(app.VScaleEdit(VI), 'ForegroundColor', 'r', 'TooltipString', app.WarningString)
                    set(app.VCountEdit(VI), 'ForegroundColor', 'r', 'TooltipString', app.WarningString)
                    set(app.VEditCheckBox(VI), 'Value', 0)
                end
            end
            delete(wb)
            movegui(app.Figure, 'onscreen')
            PPP = get(app.Figure, 'Position');
            app.DisplayObject.EditRoadDialogueWindowPosition = [PPP(1), PPP(2)];
            figure(app.Figure)
        end % function SetValues(app)
        
        function Cancel(app, ~, ~)
            app.SetValues
        end % function Cancel(app, ~, ~)
        
        function Apply(app, ~, ~)
            %[~, RCI] = ismember(app.RoadSegment.RoadClass, app.RoadClassString);
            set(app.Figure, 'Pointer', 'watch'), pause(0.01)
            if app.NumRoads == 1
                % Road Class
                RCI = get(app.RoadClassDropDown, 'Value');
                app.RoadSegment.RoadClass = app.RoadClassString{RCI};
                % Tree Factor
                switch get(app.TreeFactorDropDown, 'Value')
                    case 1
                        app.RoadSegment.TreeFactor = 1;
                    case 2
                        app.RoadSegment.TreeFactor = 1.25;
                    case 3
                        app.RoadSegment.TreeFactor = 1.5;
                    otherwise
                        error('EditRoadDialogue:Apply:TreeFactor', 'Tree Factor should be 1, 1.25 or 1.5')
                end
                SCI = get(app.SpeedClassDropDown, 'Value');
                if isequal(app.RoadSegment.SpeedClass, app.RoadSegment.SpeedClassCorrect)
                    app.RoadSegment.SpeedClass = app.SpeedClassString{SCI};
                else
                    app.RoadSegment.Speed = str2double(app.SpeedClassString{SCI}(3:end));
                end
                    
                app.RoadSegment.Stagnation = get(app.StagnationSlider, 'Value');

                NumVs = numel(app.VehicleBreakdown);
                VScalingPre = app.RoadSegment.VehicleScaling;
                VScalingPost = VScalingPre;
                for VI = 1:NumVs
                    V = app.VehicleBreakdown{VI};
                    if get(app.VEditCheckBox(VI), 'Value')
                        VScalingPost.(V) = get(app.VScaleSlider(VI), 'Value');
                    end
                end
                if ~isequal(VScalingPre, VScalingPost)
                    % Scaling has changed.
                    app.RoadSegment.VehicleScaling = VScalingPost;
                end
            else
                % A number of roads, but not all of them, are to be
                % changed.
                NumVs = numel(app.VehicleBreakdown);
                for RI = app.RoadSegmentIndices
                    VScalingPre = app.RoadNetwork.RoadSegments(RI).VehicleScaling;
                    VScalingPost = VScalingPre;
                    for VI = 1:NumVs
                        V = app.VehicleBreakdown{VI};
                        if get(app.VEditCheckBox(VI), 'Value')
                            VScalingPost.(V) = get(app.VScaleSlider(VI), 'Value');
                        end
                    end
                   if ~isequal(VScalingPre, VScalingPost)
                       % Scaling has changed.
                       fprintf('Changing scaling for road %d.\n', RI)
                       app.RoadNetwork.RoadSegments(RI).VehicleScaling = VScalingPost;
                   end            
                end
            end
            app.DisplayObject.RefreshPlot
            app.SetValues
            set(app.Figure, 'Pointer', 'arrow')
        end % function Apply(app, ~, ~)
        
        function PrevRoad(app, ~, ~)
            if isequal(app.RoadSegmentIndex, 1)
                app.RoadSegmentIndices = app.RoadNetwork.NumRoads;
            else
                app.RoadSegmentIndices = app.RoadSegmentIndices - 1;
            end
        end % function PrevRoad(app, ~, ~)
        
        function NextRoad(app, ~, ~)
            if isequal(app.RoadSegmentIndex, app.RoadNetwork.NumRoads)
                app.RoadSegmentIndices = 1;
            else
                app.RoadSegmentIndices = app.RoadSegmentIndices + 1;
            end
        end % function PrevRoad(app, ~, ~)
        
        function Recalculate(app, ~, ~)
            app.DisplayObject.Recalculate;
            app.SetValues;
        end % function Recalculate(app, ~, ~)
        
        function CloseFunction(app, ~, ~)
            PPP = get(app.Figure, 'Position');
            app.DisplayObject.EditRoadDialogueWindowPosition = [PPP(1), PPP(2)];
            delete(app.Figure)
        end % function CloseFunction(app, ~, ~)
    end % methods
end % classdef EditRoadDialogue < handle