classdef SRM1Display < handle
    % SRM1DISPLAY
    % A GUI that displays and controls an SRM1ModelObject.
    %
    % USAGE
    % SRM1Display           - Will invite the user to nominate a saved
    %                         SRM1Model file, or to create a new one from a
    %                         road network shape file.
    % SRM1Display(filename) - Will open a saved SRM1Model file.
    %
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % $Workfile:   SRM1Display.m  $
    % $Revision:   1.2  $
    % $Author:   edward.barratt  $
    % $Date:   Nov 25 2016 11:46:08  $
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    
    properties
        Instance
        MapAxes
        ColorBar
        %BackgroundMapDirectory = 'C:\Users\edward.barratt\Data\GIS_Data\AberdeenBackgroundMaps'      
    end % properties
    
    properties (Dependent)
        Figure
        AverageWindSpeed
        BackgroundColor
        PlottedRoads
        Pollutant
        EmissionFactorClassName
        PtSize
        DisplayModelledPointConcentrations
        DisplayBackgroundMap
        DisplayGrid
        DisplayRoad
        SelectedRoad
        RoadSelectionMode
        RoadColorMode
        Limit
        ColorMap
        CalculationDistance
        CalculationDistanceMode
        CalculationDistanceModeAllowedValues
        BackgroundNO2
        BackgroundNOx
        BackgroundPM10
        BackgroundPM25
        BackgroundO3
        RoadPlotWidth
        SelectedRoadPlotWidth
        BackgroundMapDirectory
    end % properties (Dependent)
        
    properties (SetAccess = private)
        MapView@MapViewer
        PlottedPoints
        RoadLegend
        AllowedPollutants = {'NOx', 'NO2', 'PM10', 'PM25'}
        Limits = struct('PM10', 40, 'PM25', 25, 'NO2', 40, 'NOx', 30)
    end % properties (SetAccess = private)
    
    properties (Dependent, SetAccess = private)
        Model
        PtXs
        PtYs
        PtExtents
        RdXMins
        RdXMaxs
        RdYMins
        RdYMaxs
        RdExtents
        FullExtents
        PointConcentrations
        RoadConcentrations
        CAxisLimits
        RoadConcentrationDividers
    end % properties (Dependent, SetAccess = private)
        
    properties (Dependent, Hidden)
        SetMapExtents
        FigureName
        FigTag
        CMapValues
    end % properties (Dependent, Hidden)
    
    properties (Hidden)
        FMenu
        PMenu
        SMenu
        EditRoadDialogueWindow
        EditRoadDialogueWindowPosition = [100, 100]
        SettingsDialogueWindow
        SettingsDialogueWindowPosition = [100, 100]
        
        CMapRGBs = [1.0, 1.0, 0.7; 0.7, 1.0, 0.7; 0.7, 0.7, 1.0; 0.2, 0.2, 1.0; 1.0, 0.0, 0.0; 0.0, 0.0, 0.0];
        
        FigurePos = [20, 20, 800, 700]
        StandardRoadColor = [0, 0, 0]
    end % properties (Hidden)
    
    properties (GetAccess = private, SetAccess = private)
        ModelP@SRM1Model
        PtSizeP = 5
        RCMenu
        RCMenu_All
        RCMenu_This
        RCMenu_Select
        PlottedRoadsP
        SelectedRoadsIP = []
        RoadSelectionModeP = 'Create'
        RoadColorModeP = ''
        CurrentRoadColors@cell
        BackgroundColorP = [1, 1, 1]
        RoadPlotWidthP = 1
    end % properties (GetAccess = private, SetAccess = private)
    
    methods
        
        %% Constructor
        function app = SRM1Display(varargin)
            app.Instance = sprintf('SRM1D_%s_%04d', datestr(now, 'yyyymmddHHMMSSFFF'), randi(9999));
            if nargin > 0
                AssignedModel = varargin{1};
            else
                AssignedModel = app.SetUpMenu;
                if isequal(AssignedModel, 0)
                    return
                end
            end
                
            switch class(AssignedModel)
                case 'SRM1Model'
                    app.ModelP = AssignedModel;
                case 'char'
                    AssignedModel = SRM1Model.OpenFile(AssignedModel);
                otherwise
                    error('GRRRRRRRRRRRRRRRRRR!')
            end
            app.ModelP = AssignedModel;
            app.ModelP.DisplayObject = app;
            % Build the viewer
            app.BuildViewer
            % Plot the modelled values.
            app.PlottedPoints = scatter(app.MapAxes, app.PtXs, app.PtYs, app.PtSize, app.PointConcentrations, 'filled');
            % Plot the road network.
            app.PlottedRoads = plot(app.MapAxes, app.Model.RoadNetwork.XVertices', app.Model.RoadNetwork.YVertices', 'Color', app.StandardRoadColor, 'LineWidth', app.RoadPlotWidth, 'uicontextmenu', app.RCMenu);
            app.RoadLegend = legend(app.PlottedRoads(1), 'Roads', 'Location', 'southwest');
            % Decide which parts will be visible.
            %app.MapView
            app.MapView.PlotMapImages = app.DisplayBackgroundMap;
            app.MapView.PlotGridLines = app.DisplayGrid;
            set(app.PlottedPoints, 'Visible', onOrOff(app.DisplayModelledPointConcentrations))
            set(app.PlottedRoads, 'Visible', onOrOff(app.DisplayRoad))
            % Plot the color bar.
            app.DoColorMapAndBar
            if app.Model.NumPoints == 0
                app.RoadColorMode = 'Concentration';
                app.RoadPlotWidth = 4;
            else
                app.RoadColorMode = 'SimpleLine';
                app.RoadPlotWidth = 1;
            end
        end % function app = SRM1Display(AssignedModel)
        
        %% Getters
        function val = get.Figure(app)
            val = findall(0, 'Tag', app.FigTag);
        end % function val = get.figure(app)
        
        function val = get.FigTag(app)
            val = sprintf('%s_MAIN', app.Instance);
        end % function val = get.FigTag(app)
        
        function val = get.AverageWindSpeed(app)
            val = app.Model.AverageWindSpeed;
        end % function val = get.AverageWindSpeed(app)
        
        function val = get.BackgroundColor(app)
            val = app.BackgroundColorP;
        end % function val = get.BackgroundColor(app)
        
        function val = get.PlottedRoads(app)
            val = app.PlottedRoadsP;
        end % function val = get.PlottedRoads(app)
        
        function val = get.Model(app)
            val = app.ModelP;
        end % function val = get.Model(app)
        
        function val = get.PtSize(app)
            val = app.PtSizeP;
        end % function val = get.PtSize(app)
        
        function val = get.Pollutant(app)
            val = app.Model.Pollutant;
        end % function val = get.Pollutant(app)
        
        function val = get.EmissionFactorClassName(app)
            val = app.Model.EmissionFactorClassName;
        end % function val = get.EmissionFactorClassName(app)
        
        function set.EmissionFactorClassName(app, val)
            OldClassName = app.Model.EmissionFactorClassName;
            if ~isequal(val, OldClassName)
                app.Model.EmissionFactorClassName = val;
            end
        end % function set.EmissionFactorClassName(app, val)
        
        function val = get.PtXs(app)
            val = app.Model.CP_X;
        end % function val = get.PtXs(app)
        
        function val = get.PtYs(app)
            val = app.Model.CP_Y;
        end % function val = get.PtYs(app)
        
        function val = get.RdXMins(app)
            val = app.Model.RoadNetwork.XMins;
        end % function val = get.RdXMins(app)
        
        function val = get.RdYMins(app)
            val = app.Model.RoadNetwork.YMins;
        end % function val = get.RdYMins(app)
                
        function val = get.RdXMaxs(app)
            val = app.Model.RoadNetwork.XMaxs;
        end % function val = get.RdXMaxs(app)
        
        function val = get.RdYMaxs(app)
            val = app.Model.RoadNetwork.YMaxs;
        end % function val = get.RdYMaxs(app)
        
        function val = get.PtExtents(app)
            val = [min(app.PtXs), max(app.PtXs), min(app.PtYs), max(app.PtYs)];
        end % function val = get.PtExtents(app)
        
        function val = get.RdExtents(app)
            val = [min(app.RdXMins), max(app.RdXMaxs), min(app.RdYMins), max(app.RdYMaxs)];
        end % function val = get.RdExtents(app)
        
        function val = get.FullExtents(app)
            AreRds = app.Model.NumRoads > 0;
            ArePts = app.Model.NumPoints > 0;
            if AreRds && ArePts
                minP = min([app.RdExtents; app.PtExtents]);
                maxP = max([app.RdExtents; app.PtExtents]);
                Ex = [minP(1), maxP(2), minP(3), maxP(4)];    
            elseif AreRds
                Ex = app.RdExtents;
            elseif ArePts
                Ex = app.PtExtents;
            else
                error('SRM1Display:GetFullExtents:NoRoadsOrPoints', 'No roads or calculation points are specified yet.')
            end
            Ex(1) = floor(Ex(1));
            Ex(2) = ceil(Ex(2));
            Ex(3) = floor(Ex(3));
            Ex(4) = ceil(Ex(4));
            val = Ex;
        end % function val = get.FullExtents(app)
        
        function val = get.SetMapExtents(app)
            XRange2 = (app.RdExtents(2) - app.RdExtents(1))/2;
            YRange2 = (app.RdExtents(4) - app.RdExtents(3))/2;
            XMid = mean([app.RdExtents(2), app.RdExtents(1)]);
            YMid = mean([app.RdExtents(4), app.RdExtents(3)]);
            if XRange2 > YRange2
                Ex = [XMid - YRange2, XMid + YRange2, YMid - YRange2, YMid + YRange2];
            else
                Ex = [XMid - XRange2, XMid + XRange2, YMid - XRange2, YMid + XRange2];
            end
            Ex(1) = floor(Ex(1));
            Ex(2) = ceil(Ex(2));
            Ex(3) = floor(Ex(3));
            Ex(4) = ceil(Ex(4));
            val = Ex;
        end % function val = get.SetMapExtents(app)
        
        function val = get.PointConcentrations(app)
            val = app.Model.PointConcentrations.(app.Pollutant);
        end % function val = get.PointConcentrations(app)
        
        function val = get.RoadConcentrations(app)
            val = app.Model.RoadConcentrations.(app.Pollutant);
        end % function val = get.RoadConcentrations(app)
        
        function val = get.CAxisLimits(app)
            MX = max(app.PointConcentrations);
            if MX > app.Limit+10
                val = [0, MX];
            else
                val = [0, app.Limit+10];
            end
        end % function val = get.CAxisLimits(app)
        
        function val = get.Limit(app)
            val = app.Limits.(app.Pollutant);
        end % function val = get.Limit(app)
        
        function val = get.DisplayModelledPointConcentrations(app)
            val = app.Model.DisplayModelledPointConcentrations;
        end % function val = get.DisplayModelledPointConcentrations(app)
        
        function val = get.DisplayBackgroundMap(app)
            val = app.Model.DisplayBackgroundMap;
        end % function val = get.DisplayBackgroundMap(app)
        
        function val = get.DisplayGrid(app)
            val = app.Model.DisplayGrid;
        end % function val = get.DisplayGrid(app)
        
        function val = get.DisplayRoad(app)
            val = app.Model.DisplayRoad;
        end % function val = get.DisplayRoad(app)
        
        function val = get.SelectedRoad(app)
            val = app.SelectedRoadsIP;
            %app.SelectedRoadsIP = app.Model.RoadNetwork.RoadSegments(RI);
        end % function val = get.SelectedRoad(app)
        
        function val = get.RoadSelectionMode(app)
            val = app.RoadSelectionModeP;
        end % function val = get.RoadSelectionMode(app)
        
        function val = get.RoadColorMode(app)
            val = app.RoadColorModeP;
        end % function val = get.RoadSelectionMode(app)
        
        function val = get.ColorMap(app)
            Values = app.CMapValues;
            RGBs = app.CMapRGBs;
            val = CreateColormap(Values, RGBs, 'MinPlot', min(app.PointConcentrations), 'MaxPlot', max(app.PointConcentrations));
        end % function val = get.ColorMap(app)
        
        function val = get.CalculationDistance(app)
            val = app.Model.CalculationDistance;
        end % function val = get.CalculationDistance(app)
        
        function val = get.CalculationDistanceMode(app)
            val = app.Model.CalculationDistanceMode;
        end % function val = get.CalculationDistanceMode(app)
        
        function val = get.CalculationDistanceModeAllowedValues(app)
            val = app.Model.CalculationDistanceModeAllowedValues;
        end % function val = get.CalculationDistanceModeAllowedValues(app)
        
        function val = get.BackgroundPM10(app)
            val = app.Model.BackgroundPM10;
        end % function val = get.BackgroundPM10(app)
        
        function val = get.BackgroundPM25(app)
            val = app.Model.BackgroundPM25;
        end % function val = get.BackgroundPM25(app)
        
        function val = get.BackgroundNOx(app)
            val = app.Model.BackgroundNOx;
        end % function val = get.BackgroundNOx(app)
        
        function val = get.BackgroundNO2(app)
            val = app.Model.BackgroundNO2;
        end % function val = get.BackgroundNO2(app)
        
        function val = get.BackgroundO3(app)
            val = app.Model.BackgroundO3;
        end % function val = get.BackgroundO3(app)
            
        function val = GetConcColor(app, Value)
            Vs = app.CMapValues;
            RGBs = app.CMapRGBs;
            R = interp1(Vs, RGBs(:, 1), Value);
            G = interp1(Vs, RGBs(:, 2), Value);
            B = interp1(Vs, RGBs(:, 3), Value);
            val = [R, G, B];
        end % function val = GetConcColor(app, Value)
        
        function val = get.FigureName(app)
            [~, fn, ex] = fileparts(app.Model.FileLocation);
            fn = [fn, ex];
            val = sprintf('SRM1Display: %s', fn);
        end % function val = get.FigureName(app)
        
        function val = get.CMapValues(app)
            Limit_ = app.Limit;
            val = [0, Limit_*0.5, Limit_*0.75, Limit_, Limit_+0.000001, app.CAxisLimits(2)];
        end % function val = get.CMapValues(app)
        
        function val = get.RoadPlotWidth(app)
            val = app.RoadPlotWidthP;
        end % function val = get.SelectedRoadPlotWidth(app)
        
        function val = get.SelectedRoadPlotWidth(app)
            val = app.RoadPlotWidth*2;
        end % function val = get.SelectedRoadPlotWidth(app)
        
        function val = get.RoadConcentrationDividers(app)
            Mx = ceil(max(app.RoadConcentrations));
            Limit_ = app.Limit;
            if Mx > Limit_+20
                Z = Mx;
                Y = ceil(mean([Mx, Limit_]));
            else
                Z = Limit_ + 20;
                Y = Limit_ + 10;
            end
            val = [0, app.Limit*0.5, app.Limit*0.625, app.Limit*0.875, app.Limit, Y, Z];
        end % function val = get.CMapValues(app)
        
        function val = get.BackgroundMapDirectory(app)
            val = app.Model.BackgroundMapDirectory;
        end % function val = get.BackgroundMapDirectory(app)
        
        %% Setters
        function set.AverageWindSpeed(app, val)
            if ~isequal(val, app.Model.AverageWindSpeed)
                app.Model.AverageWindSpeed = val;
            end
        end % function set.AverageWindSpeed(app, val)
        
        function set.PlottedRoads(app, val)
            app.PlottedRoadsP = val;
            app.CurrentRoadColors = get(app.PlottedRoads, 'Color');
        end % function set.PlottedRoads(app, val)
        
        function set.Model(app, val)
            app.ModelP = val;
            set(app.PlottedPoints, 'CData', app.PointConcentrations)
        end % function set.Model(app)
        
        function set.PtSize(app, val)
            app.PtSizeP = val;
            set(app.PlottedPoints, 'SizeData', val)
        end % function set.PtSize(app, val)
        
        function set.Pollutant(app, val)
            set(app.Figure, 'Pointer', 'watch'), pause(0.001)
            if ~ismember(val, app.AllowedPollutants)
                error('SRM1Display:SetPollutant:WrongPollutant', 'Pollutant must be one of ''PM10'', ''PM25'', ''NO2'', or ''NOx''.')
            end
            if ~isequal(val, app.Model.Pollutant)
                set(app.PMenu.(app.Model.Pollutant), 'Checked', 'off')
                set(app.PMenu.(val), 'Checked', 'on')
                app.Model.Pollutant = val;
            end
            set(app.Figure, 'Pointer', 'arrow')
        end % function set.Pollutant(app, val)
        
        function set.BackgroundColor(app, val)    
            set(app.MapAxes, 'Color', val)
            app.BackgroundColorP = val;
            app.SendChanges
        end % function set.BackgroundColor(app, val)
       
        
        function set.RoadSelectionMode(app, val)
            if ~isequal(val, app.RoadSelectionModeP)
                switch val
                    case 'Create'
                        app.RoadSelectionModeP = 'Create';
                        set(app.SMenu.Append, 'Checked', 'off');
                        set(app.SMenu.Create, 'Checked', 'on');
                    case 'Append'
                        app.RoadSelectionModeP = 'Append';
                        set(app.SMenu.Append, 'Checked', 'on');
                        set(app.SMenu.Create, 'Checked', 'off');
                    otherwise
                        error('SRM1Display:SetRoadSelectionMode:WrongMode', 'RoadSelectionMode must be one of ''Create'' or ''Append''.')
                end
                app.SendChanges
            end
        end % function set.RoadSelectionMode(app, val)
        
        function set.CalculationDistance(app, val)
            app.Model.CalculationDistance = val;
        end % function set.CalculationDistance(app, val)
        
        function set.CalculationDistanceMode(app, val)
            app.Model.CalculationDistanceMode = val;
        end % function set.CalculationDistance(app, val)
        
        function set.BackgroundPM10(app, val)
            app.Model.BackgroundPM10 = val;
        end % function set.BackgroundPM10(app, val)
        
        function set.BackgroundPM25(app, val)
            app.Model.BackgroundPM25 = val;
        end % function set.BackgroundPM25(app, val)
        
        
        function set.BackgroundNO2(app, val)
            app.Model.BackgroundNO2 = val;
        end % function set.BackgroundNO2(app, val)
        
        
        function set.BackgroundNOx(app, val)
            app.Model.BackgroundNOx = val;
        end % function set.BackgroundNOx(app, val)
        
        function set.BackgroundO3(app, val)
            app.Model.BackgroundO3 = val;
        end % function set.BackgroundO3(app, val)
        
        function set.RoadColorMode(app, val)
            % Wally
            if ~isequal(val, app.RoadColorModeP)
                if isequal(val, 'ForceChange')
                    % This will force the colours to change.
                    val = app.RoadColorModeP;
                end
                app.RoadColorModeP = val;
                
                switch val
                    case 'SimpleLine'
                        set(app.PlottedRoads, 'Color', app.StandardRoadColor)
                        RHs = app.PlottedRoads(1);
                        RSs = {'Roads'};
                        app.RoadPlotWidth = 1;
                        ColorsDone = 1;
                    case 'RoadClass'
                        RoadClassStrings = {'Wide Canyon', 'Narrow Canyon', 'One Sided', 'Open Road'};
                        Colors = [1, 0.5, 0; ...  % Orange for wide canyons 
                                  1, 0  , 0; ...  % Red for narrow canyons
                                  1, 0  , 1; ...  % Magenta for one sided canyons
                                  0, 1  , 0];     % Green for open roads.
                        RoadClasses = app.Model.RoadNetwork.RoadClasses;
                        RoadColors = Colors(RoadClasses, :);
                        ColorsDone = 0;
                        RHs = [];
                        RSs = {};
                        for SC = 1:4
                            [Q, W] = ismember(SC, RoadClasses);
                            if Q
                                RHs(end+1) = app.PlottedRoads(W); %#ok<AGROW>
                                RSs{end+1} = RoadClassStrings{SC}; %#ok<AGROW>
                            end
                        end 
                        app.RoadPlotWidth = 4;
                    case 'SpeedClass'
                        Colors = [1, 0.5, 0; ...  % Red for stagnated 
                                  1, 0.5, 0; ...  % Orange for normal
                                  0, 0  , 1; ...  % Blue for smooth
                                  0, 1  , 0];     % Green for large roads
                        SpeedClassCorrect = app.Model.RoadNetwork.RoadSegments(1).SpeedClassCorrect;
                        if ismember(SpeedClassCorrect, {'Stagnated', 'Normal', 'Smooth', 'LargeRoad'})
                            SpeedClasses = app.Model.RoadNetwork.SpeedClasses;
                            SpeedClassStrings = {'Stagnated', 'Normal City', 'Smooth City', 'Large Roads'};
                        else
                            SpeedClasses = ones(1, app.Model.RoadNetwork.NumRoads);
                            Speeds = app.Model.RoadNetwork.Speeds;
                            SpeedClasses(Speeds >= 15) = 2;
                            SpeedClasses(Speeds >= 30) = 3;
                            SpeedClasses(Speeds >= 45) = 4;
                            SpeedClassStrings = {'< 15 km/s', '15 - 30 km/s', '30 - 45 km/s', '> 45 km/s'};
                        end
                        RoadColors = Colors(SpeedClasses, :);
                        RHs = [];
                        RSs = {};
                        for SC = 1:4
                            [Q, W] = ismember(SC, SpeedClasses);
                            if Q
                                RHs(end+1) = app.PlottedRoads(W); %#ok<AGROW>
                                RSs{end+1} = SpeedClassStrings{SC}; %#ok<AGROW>
                            end
                        end 
                        app.RoadPlotWidth = 4;
                        ColorsDone = 0;
                    case 'Stagnation'
                        Colors = [0.7, 0.7, 0.9; ...  % Blue Grey
                                    0,   0, 1; ...    % Blue
                                    0,   1, 1; ...    % Cyan
                                    0,   1, 0; ...    % Green
                                    1, 0.5, 0; ...    % Orange  Because yellow doesn't show well
                                    1,   0, 0; ...    % Red
                                    1,   0, 1; ...    % Magenta
                                    0,   0, 0];       % Black
                        StagClassDividers = [0, 0.05, 0.1, 0.2, 0.4, 0.6, 0.8, 1];
                        StagClassStrings = {  '0 - 5%',  '5 - 10%', '10 - 20%', ...
                                            '20 - 40%', '40 - 60%', '60 - 80%', ...
                                            '80 - 100%'};
                        StagnationClasses = -999*ones(1, app.Model.NumRoads);
                        Stags = app.Model.RoadNetwork.StagnationFactors;
                        StagsU = unique(Stags);
                        RHs = [];
                        RSs = {};
                        if numel(StagsU) > 8
                            for Si = 1:numel(StagClassStrings)
                                A = StagClassDividers(Si);
                                B = StagClassDividers(Si+1);
                                StagnationClasses(IsBetween(Stags, A, B, 'LowerEquiv', 1, 'UpperEquiv', 0)) = Si+1;
                                [Q, W] = ismember(Si, StagnationClasses);
                                if Q
                                    RHs(end+1) = app.PlottedRoads(W); %#ok<AGROW>
                                    RSs{end+1} = StagClassStrings{Si}; %#ok<AGROW>
                                end
                            end
                        else
                            for Si = 1:numel(StagsU)
                                StagU = StagsU(Si);
                                StagnationClasses(Stags == StagU) = Si;
                                [Q, W] = ismember(Si, StagnationClasses);
                                if Q
                                    RHs(end+1) = app.PlottedRoads(W); %#ok<AGROW>
                                    SP = StagU*100;
                                    RSs{end+1} = sprintf('%3.*f%%', DecPlaces(SP), SP); %#ok<AGROW>
                                end
                            end
                        end
                        RoadColors = Colors(StagnationClasses, :);
                        app.RoadPlotWidth = 4;
                        ColorsDone = 0;
                    case 'Traffic'
                        Colors = [  0,   0, 1; ...    % Blue
                                    0,   1, 1; ...    % Cyan
                                    0,   1, 0; ...    % Green
                                    1, 0.5, 0; ...    % Orange  Because yellow doesn't show well
                                    1,   0, 0; ...    % Red
                                    1,   0, 1; ...    % Magenta
                                    0,   0, 0];       % Black
                        TrafficClasses = -999*ones(1, app.Model.NumRoads);
                        TrafficTotals = app.Model.RoadNetwork.TrafficTotalsScaled;
                        MN = min(TrafficTotals);
                        MX = max(TrafficTotals);
                        Range = MX-MN;
                        Lange = log10(Range);
                        TrafClassDividers = linspace(MN, MX, 8);
                        TrafClassDividers(end) = ceil(TrafClassDividers(end));
                        LY = floor(Lange - 0.92);
                        TrafClassDividers(2:end-1) = 10^LY*round(TrafClassDividers(2:end-1)/10^LY);
                        
                        RHs = [];
                        RSs = {};
                        for Si = 1:numel(TrafClassDividers)-1
                            A = TrafClassDividers(Si);
                            B = TrafClassDividers(Si+1);
                            if Si == numel(TrafClassDividers)-1
                                TrafficClasses(IsBetween(TrafficTotals, A, B, 'LowerEquiv', 1, 'UpperEquiv', 1)) = Si;
                            else
                                TrafficClasses(IsBetween(TrafficTotals, A, B, 'LowerEquiv', 1, 'UpperEquiv', 0)) = Si;
                            end
                            [Q, W] = ismember(Si, TrafficClasses);
                            if Q
                                RHs(end+1) = app.PlottedRoads(W); %#ok<AGROW>
                                RSs{end+1} = sprintf('%.*f to %.*f', DecPlaces(A), A, DecPlaces(B), B); %#ok<AGROW>
                            end
                        end
                        RSs{end} = sprintf('%s AADF', RSs{end});
                        RoadColors = Colors(TrafficClasses, :);
                        app.RoadPlotWidth = 4;
                        ColorsDone = 0;
                    case 'Emissions'
                        Colors = [  0,   0, 1; ...    % Blue
                                    0,   1, 1; ...    % Cyan
                                    0,   1, 0; ...    % Green
                                    1, 0.5, 0; ...    % Orange  Because yellow doesn't show well
                                    1,   0, 0; ...    % Red
                                    1,   0, 1; ...    % Magenta
                                    0,   0, 0];       % Black
                        EmissionClasses = -999*ones(1, app.Model.NumRoads);
                        EString = sprintf('Emissions%s', app.Pollutant);
                        Emissions = app.Model.RoadNetwork.(EString)/1000;
                        MN = min(Emissions);
                        MX = max(Emissions);
                        Range = MX-MN;
                        Lange = log10(Range);
                        EmissionsClassDividers = linspace(MN, MX, 8);
                        EmissionsClassDividers(end) = ceil(EmissionsClassDividers(end));
                        LY = floor(Lange - 0.92);
                        EmissionsClassDividers(2:end-1) = 10^LY*round(EmissionsClassDividers(2:end-1)/10^LY);
                        
                        RHs = [];
                        RSs = {};
                        for Si = 1:numel(EmissionsClassDividers)-1
                            A = EmissionsClassDividers(Si);
                            B = EmissionsClassDividers(Si+1);
                            if Si == numel(EmissionsClassDividers)-1
                                EmissionClasses(IsBetween(Emissions, A, B, 'LowerEquiv', 1, 'UpperEquiv', 1)) = Si;
                            else
                                EmissionClasses(IsBetween(Emissions, A, B, 'LowerEquiv', 1, 'UpperEquiv', 0)) = Si;
                            end
                            [Q, W] = ismember(Si, EmissionClasses);
                            if Q
                                RHs(end+1) = app.PlottedRoads(W); %#ok<AGROW>
                                RSs{end+1} = sprintf('%.*f to %.*f', DecPlaces(A), A, DecPlaces(B), B); %#ok<AGROW>
                            end
                        end
                        RSs{end} = sprintf('%s ug/km s', RSs{end});
                        RoadColors = Colors(EmissionClasses, :);                        
                        app.RoadPlotWidth = 4;
                        ColorsDone = 0;
                    case 'Concentration'
                        Colors = app.CMapRGBs;
                        ConcentrationClasses = -999*ones(1, app.Model.NumRoads);
                        Concentrations = app.RoadConcentrations;
                        ConcentrationDividers = app.RoadConcentrationDividers;
                        RHs = [];
                        RSs = {};
                        for Si = 1:numel(ConcentrationDividers)-1
                            A = ConcentrationDividers(Si);
                            B = ConcentrationDividers(Si+1);
                            if Si == numel(ConcentrationDividers)-1
                                ConcentrationClasses(IsBetween(Concentrations, A, B, 'LowerEquiv', 1, 'UpperEquiv', 1)) = Si;
                            else
                                ConcentrationClasses(IsBetween(Concentrations, A, B, 'LowerEquiv', 1, 'UpperEquiv', 0)) = Si;
                            end
                            [Q, W] = ismember(Si, ConcentrationClasses);
                            if Q
                                RHs(end+1) = app.PlottedRoads(W); %#ok<AGROW>
                                RSs{end+1} = sprintf('%.*f to %.*f', DecPlaces(A), A, DecPlaces(B), B); %#ok<AGROW>
                            end
                        end
                        RSs{end} = sprintf('%s ug/m3', RSs{end});
                        ConcentrationClasses(ConcentrationClasses == -999) = 1;
                        RoadColors = Colors(ConcentrationClasses, :);
                        app.RoadPlotWidth = 4;
                        ColorsDone = 0;
                    otherwise
                            error('SRM1Display:SetRoadColorMode:WrongMode', 'RoadColorMode must be one of ''SimpleMode'', ''Concentration'', ''RoadClass'', or ''SpeedClass''.')
                end
                
                if ~ColorsDone
                    for PRi = 1:app.Model.RoadNetwork.NumRoads
                        PR = app.PlottedRoads(PRi);
                        set(PR, 'Color', RoadColors(PRi, :))
                    end
                end
                if ishghandle(app.RoadLegend)
                    delete(app.RoadLegend)
                end
                app.RoadLegend = legend(RHs, RSs, 'Location', 'southwest');
            end   
        end % function set.RoadColorMode(app, val)
        
        function set.DisplayModelledPointConcentrations(app, val)
            if val ~= app.Model.DisplayModelledPointConcentrations
                if val == 0
                    set(app.PlottedPoints, 'Visible', 'off')
                elseif val == 1
                    set(app.PlottedPoints, 'Visible', 'on')
                else
                    error('DisplayADMS:DisplayBackgroundMap:Not0or1', 'DisplayBackgroundMap must be set to 0 or 1.')
                end
                app.Model.DisplayModelledPointConcentrations = val;
                app.DoColorMapAndBar
                app.SendChanges
            end
        end % function set.DisplayModelledPointConcentrations(app, val)

        function set.DisplayRoad(app, val)
            if val ~= app.Model.DisplayRoad
                if val == 0
                    set(app.PlottedRoads, 'Visible', 'off')
                elseif val == 1
                    set(app.PlottedRoads, 'Visible', 'on')
                else
                    error('DisplayADMS:DisplayRoad:Not0or1', 'DisplayBackgroundMap must be set to 0 or 1.')
                end
                app.Model.DisplayRoad = val;
                app.SendChanges
            end
        end % function set.DisplayRoad(app, val)
        
        function set.DisplayBackgroundMap(app, val)
            if val ~= app.Model.DisplayBackgroundMap
                if ~ismember(val , [0, 1])
                    error('DisplayADMS:DisplayBackgroundMap:Not0or1', 'DisplayBackgroundMap must be set to 0 or 1.')
                end
                app.MapView.PlotMapImages = val;
                app.Model.DisplayBackgroundMap = val;
                app.SendChanges
            end
        end % function set.DisplayBackgroundMap(app, val)
        
        function set.DisplayGrid(app, val)
            if val ~= app.Model.DisplayGrid
                if ~ismember(val, [0,1])
                    error('DisplayADMS:DisplayGrid:Not0or1', 'DisplayGrid must be set to 0 or 1.')
                end
                app.MapView.PlotGridLines = val;
                app.Model.DisplayGrid = val;
            end
        end % function set.DisplayGrid(app, val)  
        
        function set.SelectedRoad(app, val)
            if numel(val) == 0
                % No roads specified. Clear selection.
                app.ClearSelection
            else
                % Is it an array of integers?
                if sum(mod(val, 1)) == 0
                    % Yes it is. So assume it's the array of indices of the
                    % roads to be selected.
                    RoadIndices = val;
                    RType = 'Index';
                else
                    % No it's not. 
                    % Check the first one...
                    if isa(val(1), 'SRM1:RoadSegment')
                        % Is it a road segment?
                        RType = 'Object';
                    elseif ismember(val(1), app.PlottedRoads)
                        % Is it a plotted line?
                        RType = 'Line';
                    else
                        error('SRM1Display:SetSelectedRoad:BadType', 'Cannot understand road segment of type ''%s''.',class(val(1)))
                    end
                    RoadIndices = [];
                    for v = val
                        switch RType
                            case 'Object'
                                [IsM, RI] = ismember(v, app.Model.RoadNetwork.RoadSegments);
                                if IsM
                                    RoadIndices(end+1) = RI; %#ok<AGROW>
                                else
                                    error('SRM1Display:SetSelectedRoad:BadTypeB', 'Atleast one of the specified road segments is not a member of the specified road network.')
                                end
                            case 'Line'
                                [IsM, RI] = ismember(val, app.PlottedRoads);
                                if IsM
                                    RoadIndices(end+1) = RI; %#ok<AGROW>
                                else
                                    error('SRM1Display:SetSelectedRoad:BadTypeC', 'Atleast one of the specified road segments is not a plotted road on the map.')
                                end
                            otherwise
                                error('Euuujjkk?')
                        end
                    end
                end
                
                if numel(RoadIndices) == 1
                    % One road specified. So our behaviour is determined by the
                    % selection mode.
                    SelectedRoadsIP_ = app.SelectedRoadsIP;
                    NumSelected = numel(SelectedRoadsIP_);
                    if NumSelected
                        % Already some selected.
                        % Is the pressed one already selected?
                        [IsM, YH] = ismember(RoadIndices, SelectedRoadsIP_);
                        if IsM
                            % It is. Remove it.
                            if isequal(RType, 'Line')
                                SelectedRoadsIP_(YH) = [];
                            end
                        else
                            % It is not.
                            % is the selection mode append?
                            if isequal(app.RoadSelectionMode, 'Append')
                                % It is. Add the new street to the selection.
                                SelectedRoadsIP_(end+1) = RoadIndices;
                            else
                                % It is not. So just set the new street as the
                                % total selection.
                                SelectedRoadsIP_ = RoadIndices;
                            end
                        end
                    else
                        % None selected, so select this one.
                        SelectedRoadsIP_ = RoadIndices;
                    end
                elseif numel(RoadIndices) > 1
                    % Multiple roads specified, so set the selected roads to be
                    % these roads and ignore the selection mode.
                    SelectedRoadsIP_ = RoadIndices;
                end

                app.SelectedRoadsIP = sort(unique(SelectedRoadsIP_));   
                NumSelected = numel(app.SelectedRoadsIP);
                if NumSelected == 0
                    set(app.RCMenu_This, 'Enable', 'off')
                    set(app.RCMenu_Select, 'Enable', 'off')
                elseif NumSelected == 1
                    set(app.RCMenu_This, 'Enable', 'on')
                    set(app.RCMenu_Select, 'Enable', 'off')
                else
                    set(app.RCMenu_This, 'Enable', 'off')
                    set(app.RCMenu_Select, 'Enable', 'on')
                end
                set(app.PlottedRoads, 'LineWidth', app.RoadPlotWidth)
                if numel(app.SelectedRoadsIP) > 0
                    if numel(app.SelectedRoadsIP) < numel(app.PlottedRoads)
                        set(app.PlottedRoads(app.SelectedRoadsIP), 'LineWidth', app.SelectedRoadPlotWidth)
                    end
                end
            end
        end % function set.SelectedRoad(app, val)
        
        function set.RoadPlotWidth(app, val)
            app.RoadPlotWidthP = val;
            set(app.PlottedRoads, 'LineWidth', val)
            if numel(app.SelectedRoadsIP) > 0
                if numel(app.SelectedRoadsIP) < numel(app.PlottedRoads)
                    set(app.PlottedRoads(app.SelectedRoadsIP), 'LineWidth', app.SelectedRoadPlotWidth)
                end
            end
        end % function set.RoadPlotWidth(app, val)
        
        %% Other functions
        function Recalculate(app)
            % Recalculate Emissions.
            app.Model.CalculatePointTrafficContributions
            app.SendChanges
        end % function Recalculate(app)
        
        function RefreshPlot(app, varargin)
            %get(app.PlottedPoints, 'CData');
            %app.PointConcentrations;
            % Check calculated point changes first.
            ReplotPoints = 0;
            ReplotRoads = 0;
            if ismember('Force', varargin)
                ReplotPoints = 1;
                ReplotRoads = 1;
            end
            if isequal(get(app.PlottedPoints, 'CData'), app.PointConcentrations)
                fprintf('No changes to concentrations at calculated points.\n')
            else
                fprintf('Concentrations at calculated points changed, refreshing plot.\n')
                ReplotPoints = 1;
            end
            % Check to see if the road colours need changing.
            if ~isequal(app.RoadColorMode, 'SimpleLine')
                ReplotRoads = 1;
            end
            
            cf = gcf;
            figure(app.Figure)
            if ReplotPoints
                set(app.PlottedPoints, 'CData', app.PointConcentrations)
                app.DoColorMapAndBar
            end
            if ReplotRoads
                fprintf('Changing road colours.\n')
                app.RoadColorMode = 'ForceChange';
            end
            figure(cf)
        end % function RefreshPlot(app)
        
        function ClearSelection(app, ~, ~)
            app.SelectedRoadsIP = [];
            set(app.PlottedRoads, 'LineWidth', app.RoadPlotWidth)
        end % function ClearSelection(app, ~, ~)
        
        function SetLimit(app, Pollutant, Value)
            if ~isequal(app.Limits.(Pollutant), Value)
                if Value >= 0
                    app.Limits.(Pollutant) = Value;
                    if isequal(Pollutant, app.Pollutant)
                        app.RefreshPlot('Force')
                    end
                else
                    error('SRM1Display:SetLimit:Negative', 'Limit values must be positive.')
                end
                if ~isempty(app.SettingsDialogueWindow) && ishghandle(app.SettingsDialogueWindow.Figure)
                    app.SettingsDialogueWindow.FillValues
                end
            end
        end % function SetLimit(app, 'Pollutant', Value)
        
        function SendChanges(app)
            % Instruct any child dialogues to change.            
            ChildWindows = {app.EditRoadDialogueWindow, app.SettingsDialogueWindow};
            for CWi = 1:numel(ChildWindows)
                CW = ChildWindows{CWi};
                try
                    CW.SetValues()
                catch err
                    if ~ismember(err.identifier, 'MATLAB:nonStrucReference')
                        disp(err)
                        rethrow(err)
                    end
                end
            end
            app.RefreshPlot
        end % function SendChanges(app)
    end % methods
    
    methods (Access = private)
        function BuildViewer(app)
            % Create the app window.
            ff = figure('Position', app.FigurePos, ...
                'handleVisibility', 'off', ...
                'Visible', 'off', ...
                'MenuBar', 'none', ...
                'Name', app.FigureName, ...
                'NumberTitle', 'off', ...
                'Tag', app.FigTag, ...
                'CloseRequestFcn', @app.CloseFigure); 
                 %'ResizeFcn', @app.FigureResizeCallBack, ... 'CloseRequestFcn', @app.CloseFigure, ...'pointer', 'watch', ...
            movegui(ff, 'onscreen')
            % Create the menu, and some buttons.
            app.MenusAndButtons
            % Set up the layout of the figure.
            app.MapAxes = axes('Parent', ff); %('Units', 'pixels', ... 'OuterPosition', app.MapPosition);
            set(app.MapAxes, 'Color', app.BackgroundColor)
            app.MapView = MapViewer('Directory', app.BackgroundMapDirectory, 'Axes', app.MapAxes, 'Extent', app.FullExtents);
            XLim_ = [app.SetMapExtents(1), app.SetMapExtents(2)];
            YLim_ = [app.SetMapExtents(3), app.SetMapExtents(4)];
            app.MapView.ZoomToBounds(XLim_, YLim_, 'RetainAspectRatio', 0) 
            hold(app.MapAxes, 'on')
            set(ff, 'Visible', 'on')
            hold(app.MapAxes, 'on')
        end % function BuildViewer(app)
        
        function MenusAndButtons(app)
            %% Plot control buttons
            % Keep only the pan, zoom, and data cursor buttons.
            set(app.Figure, 'Toolbar', 'figure');
            ToolBar = findall(app.Figure, 'Type', 'uitoolbar');
            Buttons = findall(ToolBar);
            Buttons = Buttons(1:end-1); % Last B is uimenu, and it causes difficulties.
            for B=Buttons'
                Type = get(B, 'Type');
                Tag = get(B, 'Tag');
                if ismember(Type, {'uitoggletool', 'uipushtool', 'uitogglesplittool'})
                    if ~ismember(Tag, {'Exploration.DataCursor', 'Exploration.ZoomIn', ...
                            'Exploration.ZoomOut', 'Exploration.Pan', ...
                            'Exploratio_n.Brushing'})
                        delete(B)
                    end
                end
            end

            % Get handles for the zoom and pan events.
            % Change the behaviour of the tool tip button
            dcm_obj = datacursormode(app.Figure);
            set(dcm_obj, 'UpdateFcn', @app.UpdateToolTip, ...
                         'SnapToDataVertex', 'off')
            h = zoom(app.Figure);
            set(h,'ActionPostCallback', @app.ZoomInPostCallback);
            h = pan(app.Figure);
            set(h, 'ActionPostCallback', @app.ZoomInPostCallback);
            % Add a menu bar.
            % File
            FMenu_ = uimenu(app.Figure, 'Label', 'File');
              uimenu(FMenu_, 'Label', 'Open...', 'Accelerator', 'O', 'Callback', @app.OpenModel, 'Enable', 'on');
              uimenu(FMenu_, 'Label', 'Save...', 'Accelerator', 'S', 'Callback', @app.SaveModel, 'Enable', 'on');
              EMenu = uimenu(FMenu_, 'Label', 'Export', 'Separator', 'on');
                app.FMenu.ExportPoint = uimenu(EMenu, 'Label', 'Point Concentrations', 'Callback', @app.ExportModel, 'Enable', 'on');
                app.FMenu.ExportRoad = uimenu(EMenu, 'Label', 'Road Concentrations', 'Callback', @app.ExportModel, 'Enable', 'on');
            CMenu = uimenu(app.Figure, 'Label', 'Control');
            % Pollutants
            app.PMenu.Menu = uimenu(CMenu, 'Label', 'Pollutant');
              app.PMenu.NO2  = uimenu(app.PMenu.Menu, 'Label', 'NO2', 'Checked', 'off', 'Callback', @app.SwitchPollutant);
              app.PMenu.NOx  = uimenu(app.PMenu.Menu, 'Label', 'NOx', 'Checked', 'off', 'Callback', @app.SwitchPollutant);
              app.PMenu.PM10 = uimenu(app.PMenu.Menu, 'Label', 'PM10', 'Checked', 'off', 'Callback', @app.SwitchPollutant);
              app.PMenu.PM25 = uimenu(app.PMenu.Menu, 'Label', 'PM2.5', 'Checked', 'off', 'Callback', @app.SwitchPollutant);
              set(app.PMenu.(app.Pollutant), 'Checked', 'on')
            % Selection Mode
            app.SMenu.Menu = uimenu(CMenu, 'Label', 'Road Selection Mode');
              app.SMenu.Create = uimenu(app.SMenu.Menu, 'Label', 'Create New Selection', 'Checked', 'on', 'Accelerator', 'j', 'Callback', @app.ChangeSelectMode);
              app.SMenu.Append = uimenu(app.SMenu.Menu, 'Label', 'Add To Selection', 'Checked', 'off', 'Accelerator', 'k', 'Callback', @app.ChangeSelectMode);
              app.SMenu.Clear = uimenu(app.SMenu.Menu, 'Label', 'Clear Selection', 'Separator', 'on', 'Accelerator', 'l', 'Callback', @app.ClearSelection);
            uimenu(CMenu, 'Label', 'Settings', 'Separator', 'on', 'Callback', @app.RaiseSettings)
             
            % Specify a uicontextmenu (right click menu)
            app.RCMenu = uicontextmenu('Parent', app.Figure, ...
                                       'Callback', @app.SelectRoad);
            app.RCMenu_This = uimenu(app.RCMenu, 'Label', 'Specify scaling for this road', 'Enable', 'on', 'Callback', @app.SpecifyScaling);
            app.RCMenu_Select  = uimenu(app.RCMenu, 'Label', 'Specify scaling for selected roads', 'Enable', 'off', 'Callback', @app.SpecifyScaling);
            app.RCMenu_All  = uimenu(app.RCMenu, 'Label', 'Specify scaling for all roads', 'Enable', 'on', 'Callback', @app.SpecifyScaling);
        end % function MenusAndButtons(app)
        
        function CloseFigure(app, ~, ~)
            ChildWindows = {app.EditRoadDialogueWindow, app.SettingsDialogueWindow};
            for CWi = 1:numel(ChildWindows)
                CW = ChildWindows{CWi};
                try
                    CW.CloseFunction()
                catch err
                    if ~ismember(err.identifier, 'MATLAB:nonStrucReference')
                        disp(err)
                        rethrow(err)
                    end
                end
            end
            app.Model.DisplayObject = SRM1Display.empty;
            delete(app.Figure)
        end % function CloseFigure(app, ~, ~)
        
        function RaiseSettings(app, ~, ~)
            % Will raise a dialogue that allows the background
            % concentrations, and the concentrtion limits, to be edited.
            if ~isempty(app.SettingsDialogueWindow) && ishghandle(app.SettingsDialogueWindow.Figure)
                figure(app.SettingsDialogueWindow.Figure)
            else
                app.SettingsDialogueWindow = SRM1.SettingsDialogue('DisplayObject', app, 'Position', app.SettingsDialogueWindowPosition);
            end
        end % function RaiseSettings(app, ~, ~)
        
        function SpecifyScaling(app, Sender, ~)
            set(app.Figure, 'Pointer', 'watch')
            try
                Pos = get(app.EditRoadDialogueWindow.Figure, 'Position');
                Exists = 1;
            catch err
                if ~ismember(err.identifier, {'MATLAB:nonStrucReference', 'MATLAB:class:InvalidHandle'})
                    disp(err)
                    rethrow(err)
                end
                Pos = app.EditRoadDialogueWindowPosition;
                Exists = 0;
            end
            
            switch Sender
                case app.RCMenu_All
                    Roads = 'All';
                otherwise
                    Roads = app.SelectedRoad;
            end
            if Exists
                app.EditRoadDialogueWindow.RoadSegmentIndices = Roads;
            else    
                app.EditRoadDialogueWindow = SRM1.EditRoadDialogue('DisplayObject', app, 'RoadSegment', Roads, 'Position', Pos);
            end
            set(app.Figure, 'Pointer', 'arrow')
        end % function SpecifyScaling(app, Object)
        
        function SelectRoad(app, ~, ~)
            app.SelectedRoad = gco;
        end % function SelectRoad(app, ~, ~)
        
        function OpenModel(app, ~, ~)
            app.Model.OpenModel
        end % function OpenModel(app, ~, ~)
        
        function SaveModel(app, ~, ~)
            app.Model.SaveModel
        end % function SaveModel(app, ~, ~)
        
        function ExportModel(app, Sender, ~)
            switch Sender
                case app.FMenu.ExportPoint
                    app.Model.ExportPointConcentrationShapeFile
                case app.FMenu.ExportRoad
                    app.Model.ExportRoadConcentrationShapeFile
                otherwise
                    error('error')
            end
        end % function ExportModel(app, ~, ~)
        
        function txt = UpdateToolTip(app, ~, event_obj)
            % Customizes text of data tips.
            pos = get(event_obj, 'Position');
            % Find the closest concentration Point.
            CPos = pos(1) + 1i*pos(2);
            CPosAll = app.PtXs + 1i*app.PtYs;
            CPosAll = abs(CPosAll - CPos);
            [~, MinI] = min(CPosAll);
            Conc = app.PointConcentrations(MinI);
            Text = {sprintf('Point %d of %d', MinI, app.Model.NumPoints), ...
                    sprintf('Easting:  %6.0f', pos(1)), ...
                    sprintf('Northing: %6.0f', pos(2)), ...
                    sprintf('Concentration: %.2f ug/m3', Conc)};
            txt = Text;
        end % function UpdateToolTip(app, ~, ~)
        
        function ZoomInPostCallback(app, ~, evd)
            try
                XLim_ = get(evd.Axes,'XLim');
                YLim_ = get(evd.Axes,'YLim');
                app.MapView.ZoomToBounds(XLim_, YLim_);
            catch err
                err %#ok<NOPRT>
                rethrow(err)
            end
        end % function ZoomInPostCallback(app, ~, evd)
        
        function SwitchPollutant(app, Sender, ~)
            switch Sender
                case app.PMenu.PM10
                    app.Pollutant = 'PM10';
                case app.PMenu.PM25
                    app.Pollutant = 'PM25';
                case app.PMenu.NO2
                    app.Pollutant = 'NO2';
                case app.PMenu.NOx
                    app.Pollutant = 'NOx';
            end
        end % function SwitchPollutant(app, Sender, ~)
        
        function ChangeSelectMode(app, Sender, ~)
            switch Sender
                case app.SMenu.Create
                    app.RoadSelectionMode = 'Create';
                case app.SMenu.Append
                    app.RoadSelectionMode = 'Append';
            end
        end % function ChangeSelectMode(app, Sender, ~)        
        
        function DoColorMapAndBar(app)
            colormap(app.MapAxes, app.ColorMap)
            caxis(app.MapAxes, app.CAxisLimits)
            if ishghandle(app.ColorBar)
                delete(app.ColorBar)
            end
            if app.DisplayModelledPointConcentrations
                app.ColorBar = colorbar('peer', app.MapAxes, 'location', 'southoutside');
                xlabel(app.ColorBar, sprintf('%s ug/m3', app.Pollutant))
            end
        end % function DoColorMapAndBar(app)    
    end % methods (Access = private)
    
    methods (Static)
        function NewModel = SetUpMenu()
            % First, choose model file, or set up new one?
            answer = questdlg('Open an existing .srm1 file, or create a new model.', 'Create New Model', 'Open', 'New', 'Cancel', 'Open');
            switch answer
                case 'New'
                    % Second, select a shape file for the roads.
                    ShapeFile = SRM1Display.GetShapeFile();
                    if isequal(ShapeFile, 0)
                        NewModel = SRM1Display.SetUpMenu();
                    else
                        % Third, specify the emission factor catalogue.
                        EFCFile = SRM1Display.SpecifyEmissionFactorCatalogue;
                        if isequal(EFCFile, 0)
                            return
                        end
                        % Forth, specify calculation points.
                        NewModel = SRM1Display.SpecifyPoints('EmissionFactorCatalogue', EFCFile);
                        NewModel.ImportRoadNetwork(ShapeFile);
                        % Fifth, Specify a few parameters.
                        Parameters = SRM1.SimpleSettings.RequestValues;
                        NewModel.AverageWindSpeed = Parameters.WindSpeed;
                        NewModel.BackgroundO3 = Parameters.Background.O3;
                        NewModel.BackgroundPM10 = Parameters.Background.PM10;
                        NewModel.BackgroundPM25 = Parameters.Background.PM25;
                        NewModel.BackgroundNO2 = Parameters.Background.NO2;
                        NewModel.BackgroundNOx = Parameters.Background.NOx;
                        % Sixth, specify a folder for background maps.
                        PP = uigetdir(pwd, 'Specify a folder containing background map RASTER files.');
                        if ~isequal(PP, 0)
                            NewModel.BackgroundMapDirectory = PP;
                        end
                        % Seventh, Specify save location.
                        [FF, PP] = uiputfile('UnnamedModel.srm1', 'Specify save location for new model');
                        if FF == 0
                            NewModel = 0;
                        else
                            NewModel.FileLocation = [PP, FF];
                            NewModel.SaveModel;
                            NewModel.CalculatePointTrafficContributions
                            NewModel.EmissionFactorClassName = NewModel.EmissionFactorCatalogue.FactorNames{1};
                            NewModel.SaveModel;
                        end
                    end
                case 'Open'
                    NewModel = SRM1Model.OpenFile;
                    if isempty(NewModel)
                        NewModel = 0;
                    end
                otherwise
                    NewModel = 0;
            end
        end % function NewModel = SetUpMenu()
            
        function ShapeFile = GetShapeFile()
            % Creating a new model file. First, instruct user to
            % specify a road network shape file.
            answer = questdlg('Step 1. Specify a road network shape file.', 'Create New Model', 'Open', 'Cancel', 'Open');
            switch answer
                case 'Open'
                    [FF, PP] = uigetfile('*.shp', 'Select road network.');
                    if isequal(FF, 0)
                        ShapeFile = SRM1Display.GetShapeFile();
                    else
                        ShapeFile = [PP, FF];
                    end
                otherwise
                    ShapeFile = 0;
            end
        end % function ShapeFile = GetShapeFile()
        
        function NewModel = SpecifyPoints(varargin)
            % Ask the user if they would like to specify their own points,
            % or create some automatically based on the road network.
            Options = struct;
            Options.EmissionFactorCatalogue = 'Default';
            Options = checkArguments(Options, varargin);
            answer = questdlg('Step 2. Specify calculation points. Would you like to specify a shape file, or would you prefer to create a point network based on the road network.', 'Create New Model', 'Open', 'None', 'Open');
            switch answer
                case 'Open'
                    [FF, PP] = uigetfile('*.shp', 'Select point network.');
                    if isequal(FF, 0)
                        NewModel = SRM1Display.SpecifyPoints();
                    else
                        ShapeFile = [PP, FF];
                        NewModel = SRM1Model('EmissionFactorCatalogue', Options.EmissionFactorCatalogue);
                        NewModel.ImportCalculationPoints(ShapeFile);
                    end
                case 'None'
                    NewModel = SRM1Model('EmissionFactorCatalogue', Options.EmissionFactorCatalogue);
                case 'New'
                    error('should not be called')
%                     % Create points beside vertices of roads, and mid way 
%                     % between vertices, at half road-widths distance from
%                     % the centre (i.e., at the road edge), and at 2 times
%                     % road_widths distance from the centre.
%                     %tic
%                     S = shaperead(ShapeFile);
%                     PtXs = [];
%                     PtYs = [];
%                     PtTypes = {};
%                     PtNames = {};
%                     for Ri = 1:numel(S)
%                         R = S(Ri);
%                         Width = R.WIDTH;
%                         if sum(isnan(R.X)) > 1
%                             error('SRM1Display:SpecifyPoints:TooManyNan', 'Too many NANs, you need to come up with a way of spliting polylines about nans.')
%                         end
%                         PtXs = R.X(1:end-1); % Trim the nan's from the end.
%                         PtYs = R.Y(1:end-1);
%                         NumPts = numel(PtXs);
%                         % Add points mid way between vertices.
%                         %PtXs_ = ones(1, NumPts*2 - 1); PtYs_ = ones(1, NumPts*2 - 1);
%                         %for PtI = 1:NumPts
%                         %    PtXs_(PtI*2-1) = PtXs(PtI);
%                         %    PtYs_(PtI*2-1) = PtYs(PtI);
%                         %    if PtI ~= NumPts
%                         %        PtXs_(PtI*2) = mean([PtXs(PtI), PtXs(PtI+1)]);
%                         %        PtYs_(PtI*2) = mean([PtYs(PtI), PtYs(PtI+1)]);
%                         %    end
%                         %end
%                         %PtXs = PtXs_; PtYs = PtYs_;
%                         %NumPts = numel(PtXs);
%                         ScalingsToDo = [-2, -1, 0, 1, 2];
%                         Types = {'OffRoad', 'RoadEdge', 'RoadCentre', 'RoadEdge', 'OffRoad'};
%                         NumScalings = numel(ScalingsToDo);
%                         PointXs = ones(1, NumPts*NumScalings);
%                         PointYs = ones(1, NumPts*NumScalings);
%                         PointTypes = cell(1, NumPts*NumScalings);
%                         PointNames = cell(1, NumPts*NumScalings);
%                         for PtI = 1:NumPts
%                             % Get a unit vector pointing along the road at
%                             % this point.
%                             Xp = PtXs(PtI); Yp = PtYs(PtI);
%                             if PtI == 1
%                                 Vector = [PtXs(PtI+1) - Xp, PtYs(PtI+1) - Yp];
%                                 Vector = Vector/norm(Vector);
%                             elseif PtI == NumPts
%                                 Vector = [Xp - PtXs(PtI-1), Yp - PtYs(PtI-1)];
%                                 Vector = Vector/norm(Vector);
%                             else
%                                 Vector1 = [Xp - PtXs(PtI-1), Yp - PtYs(PtI-1)];
%                                 Vector1 = Vector1/norm(Vector1);
%                                 Vector2 = [PtXs(PtI+1) - Xp, PtYs(PtI+1) - Yp];
%                                 Vector2 = Vector2/norm(Vector2);
%                                 Vector = Vector1 + Vector2;
%                                 Vector = Vector/norm(Vector);
%                             end
%                             % And rotate it 90 degrees.
%                             Vector = Vector*[0, -1; 1, 0];
%                             % Make it's length equal to half the road
%                             % width.
%                             Vector = Vector*Width*0.5;
%                             % And create the calculation points.
%                             for ScalingI = 1:NumScalings
%                                 Scaling = ScalingsToDo(ScalingI);
%                                 Loc = [Xp, Yp] + Vector*Scaling;
%                                 PointXs(NumScalings*PtI - ScalingI + 1) = Loc(1);
%                                 PointYs(NumScalings*PtI - ScalingI + 1) = Loc(2);
%                                 PointTypes{NumScalings*PtI - ScalingI + 1} = Types{ScalingI};
%                                 PointNames{NumScalings*PtI - ScalingI + 1} = sprintf('%s_Pt%03d', R.ROADNAME, NumScalings*PtI - ScalingI + 1);
%                             end
%                         end
%                         NumPts = numel(PointXs);
%                         for PtI = 1:NumPts
%                             %PtXs{end+1} = PointXs(PtI); %#ok<AGROW>
%                             %PtYs{end+1} = PointYs(PtI); %#ok<AGROW>
%                             PtXs(end+1) = PointXs(PtI); %#ok<AGROW>
%                             PtYs(end+1) = PointYs(PtI); %#ok<AGROW>
%                             PtTypes{end+1} = PointTypes{PtI}; %#ok<AGROW>
%                             PtNames{end+1} = PointNames{PtI}; %#ok<AGROW>
%                         end
%                         %figure()
%                         %axis equal
%                         %hold on
%                         %plot(R.X, R.Y)
%                         %scatter(PointXs, PointYs)
%                     end
%                     %Grid = [cell2mat(PtXs); cell2mat(PtYs)];
%                     %size(Grid)
%                     Grid = [PtXs; PtYs];
%                     NewModel = SRM1Model;
%                     %toc
%                     NewModel.ImportCalculationPoints(Grid, 'PointNames', PtNames, 'PointTypes', PtTypes);           
                otherwise
                    NewModel = 0;
            end
        end % function NewModel = SpecifyPoints(ShapeFile)
        
        function EFCFile = SpecifyEmissionFactorCatalogue()
            answer = questdlg('Step 2. Specify an emission factor catalogue file.', 'Specify emission factors', 'Open', 'Cancel', 'Open');
            switch answer
                case 'Open'
                    [FF, PP] = uigetfile('*.efc', 'Select emission factor catalogue file.');
                    if isequal(FF, 0)
                        EFCFile = SRM1Display.SpecifyEmissionFactorCatalogue();
                    else
                        EFCFile = [PP, FF];
                    end
                otherwise
                    EFCFile = 0;
            end
        end
    end % methods (Static)
end