classdef RoadNetwork < handle
    % RoadNetwork
    %   A RoadNetwork class for use by the SRM1 Model. It contains an array
    %   of RoadSegment objects, and various dependent properties and
    %   methods which depend on the included RoadSegments.
    %
    %   Commenting is a work in progress...
    %
    %   Designed to be used by SRM1Model.
    %
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    % $Workfile:   RoadNetwork.m  $
    % $Revision:   1.0  $
    % $Author:   edward.barratt  $
    % $Date:   Nov 24 2016 11:06:34  $
    % %%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
    
    properties
        SourceShapeFile@char
        SubSetOf  % Is this needed?
        ModelObject@SRM1Model = SRM1Model.empty
    end

    properties (Dependent)
        RoadSegments     % Read from RoadSegmentsP
        NumRoads         % Depends on RoadSegments.
        EmissionFactors  % Read from EmissionFactorsP. The set method sets
                         % the same property for all available road
                         % segments, and this will raise an error if an
                         % unsuitable set of values is assigned.
        VehicleBreakdown % The first time this is read, it is taken from
                         % the road segments and an error is raised if any
                         % road segments have a different vehicle
                         % breakdown. After that it will always be read
                         % from RoadSegmentsP.        
        VehicleScaling                 % All read from the road segments.
        VehicleScaling_AllIdentical
        VehicleScaling_AllAllIdentical
        XVertices
        YVertices
        ChangesMadeMajor % Set to 1 for changes that require a new assesment
                         % of the road network.
        ChangesMadeMinor % Set to 1 for minor changes that require a
                         % recalculation of modelled concentrations.
    end
    
    properties (Dependent, Hidden)
        % The following properties are dependent on private arrays with the
        % same names. They are automatically set when RoadSegments is set.
        % If appropriate properties of individual RoadSegments are changed,
        % then the RoadSegment class will attempt to automatically change
        % the corresponding field in these arrays.
        TrafficTotals
        TrafficTotalsScaled
        TreeFactors
        EmissionsPM10
        EmissionsPM25
        EmissionsNOx
        EmissionsNO2
        % The following arrays are also dependent on private arrays with
        % the same name, and are set when RoadSegments is set. However
        % since they are controlled by either the RoadClass property, or
        % the Vertices property of each RoadSegment, a change to either of
        % those properties on a single road segment will be considered a
        % major edit, and all properties will be re-assigned.
        DispersionCoefficientsA
        DispersionCoefficientsB
        DispersionCoefficientsC
        DispersionCoefficientsAlpha
        ImpactDistances
        %XVertices    - moved to non hidden status above.
        %YVertices    - moved to non hidden status above.
        XMins
        XMinsImpact
        XMaxs
        XMaxsImpact
        YMins
        YMinsImpact
        YMaxs
        YMaxsImpact
        RoadLengths
        LongestRoadLength
        RoadClasses
        Speeds
        SpeedClasses
        StagnationFactors
        
        TrafficContributionsPM10
        TrafficContributionsPM25
        TrafficContributionsNO2
        TrafficContributionsNOx
        
        CalculationDistance
        CalculationDistanceMode
        
    end % properties (Dependent, Hidden)
    
    properties (GetAccess = private, SetAccess = private)
        RoadSegmentsP@SRM1.RoadSegment
        EmissionFactorsP
        %DispersionCoefficientsP
        VehicleBreakdownP
        ChangesMadeMajorP = 1
        ChangesMadeMinorP = 1
        
        TreeFactorsP = []
        TrafficTotalsP = []
        TrafficTotalsScaledP = []
        EmissionsPM10P = []
        EmissionsPM25P = []
        EmissionsNOxP = []
        EmissionsNO2P = []
        DispersionCoefficientsAP = []
        DispersionCoefficientsBP = []
        DispersionCoefficientsCP = []
        DispersionCoefficientsAlphaP = []
        XVerticesP = []
        YVerticesP = []
        ImpactDistancesP = []
        XMinsP = []
        XMinsImpactP = []
        XMaxsP = []
        XMaxsImpactP = []
        YMinsP = []
        YMinsImpactP = []
        YMaxsP = []
        YMaxsImpactP = []
        RoadLengthsP = []
        LongestRoadLengthP = -999
        RoadClassesP = []
        SpeedsP = []
        SpeedClassesP = []
        StagnationFactorsP = []
        
        TrafficContributionsPM10P = []
        TrafficContributionsPM25P = []
        TrafficContributionsNO2P = []
        TrafficContributionsNOxP = []
        
        CalculationDistanceP = -999
        CalculationDistanceModeP = 'Road Centre'
        CalculationDistanceModeAllowedValues = {'Road Edge', 'Road Centre'}
    end % properties (GetAccess = private, SetAccess = private)
    
    methods
        %% Constructor
        function obj = RoadNetwork(varargin)
            if nargin == 0
                obj = RoadNetwork.empty;
            else
                Options = struct('SourceShapeFile', 'NotSpecified', ...
                                 'SubSetOf', SRM1.RoadNetwork.empty, ...
                                 'RoadSegments', SRM1.RoadSegment.empty, ...
                                 'EmissionFactors', 'Default', ...
                                 'DispersionCoefficients', 'Default', ...
                                 'VehicleBreakdown', 'NotSet');
                Options = checkArguments(Options, varargin);
                obj.SourceShapeFile = Options.SourceShapeFile;
                obj.SubSetOf = Options.SubSetOf;
                obj.RoadSegmentsP = Options.RoadSegments;
                obj.VehicleBreakdownP = Options.VehicleBreakdown;
                for RSi = 1:obj.NumRoads
                    obj.RoadSegments(RSi).ParentRoadNetwork = obj;
                end
                if ~isequal(Options.EmissionFactors, 'Default')
                    obj.EmissionFactorsP = Options.EmissionFactors;
                else
                    warning('RoadNetwork:AABBCC', 'RoadNetwork AABBCC This won''t work.')
                    obj.EmissionFactorsP = EmissionFactorDutch;
                end
                %if ~isequal(Options.DispersionCoefficients, 'Default')
                %    % Use the standard dispersion factors.
                %    [~, ~, ~, ~, obj.DispersionCoefficientsP] = SRM1.GetDispersionCoefficients('Narrow City Canyon');
                %else
                %    obj.DispersionCoefficientsP = Options.DispersionCoefficients;
                %end
            end
        end % function obj = RoadNetwork(varargin)
                
        %% Getters
        function val = get.RoadSegments(obj)
            val = obj.RoadSegmentsP;
        end % function val = get.RoadSegments(obj)
        
        function val = get.NumRoads(obj)
            val = numel(obj.RoadSegmentsP);
        end % function val = get.NumRoads(obj)
                    
        function val = get.EmissionFactors(obj)
            val = obj.EmissionFactorsP;
        end % function val = get.EmissionFactors(obj)
        
        function val = get.VehicleBreakdown(obj)
            if isequal(obj.VehicleBreakdownP, 'NotSet')
                VBD = obj.RoadSegments(1).VehicleBreakdown;
                for Ri = 2:obj.NumRoads
                    VBD_ = obj.RoadSegments(Ri).VehicleBreakdown;
                    if ~isequal(VBD, VBD_)
                        % Shouldn't happen.
                        error('SRM1:RoadNetwork:GetVehicleBreakdown:NotSameVeh', 'The vehicle breakdown for all road segments is not the same.')
                    end
                end
                obj.VehicleBreakdownP = VBD;
            end
            val = obj.VehicleBreakdownP;
        end % function val = get.VehicleBreakdown(obj)
        
        function val = get.VehicleScaling(obj)
            if obj.VehicleScaling_AllAllIdentical
                warning('SRM1:RoadNetwork:getVehicleScaling:NotAllIdentical', 'Property VehicleScaling of RoadNetwork object is for the first road segment, at least one other road segments in the object has a different scaling.')
            end
            val = obj.RoadSegments(1).VehicleScaling;
        end % function val = get.VehicleScaling(obj)
        
        function val = get.VehicleScaling_AllIdentical(obj)
            val = obj.CheckScalingIdentical;
        end % function val = get.VehicleScaling_AllIdentical(obj)
        
        function val = get.VehicleScaling_AllAllIdentical(obj)
            AllIdentical = obj.VehicleScaling_AllIdentical;
            if sum(AllIdentical) ~= numel(AllIdentical)
                val = true;
            else
                val = false;
            end
        end % function val = get.VehicleScaling_AllAllIdentical(obj)
        
        function val = get.ChangesMadeMajor(obj)
            val = obj.ChangesMadeMajorP;
        end % function val = get.ChangesMadeMajor(obj)
        
        function val = get.ChangesMadeMinor(obj)
            val = obj.ChangesMadeMinorP;
        end % function val = get.ChangesMadeMinor(obj)
        
        
        function val = get.TreeFactors(obj)
            if numel(obj.TreeFactorsP) ~= obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.TreeFactorsP;
        end % function val = get.TreeFactors(obj)
        
        function val = get.RoadClasses(obj)
            if numel(obj.RoadClassesP) ~= obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.RoadClassesP;
        end % function val = get.RoadClasses(obj)
        
        function val = get.Speeds(obj)
            if numel(obj.SpeedsP) ~= obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.SpeedsP;
        end % function val = get.Speeds(obj)
        
        function val = get.SpeedClasses(obj)
            if numel(obj.SpeedClassesP) ~= obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.SpeedClassesP;
        end % function val = get.SpeedClasses(obj)
        
        function val = get.StagnationFactors(obj)
            if numel(obj.StagnationFactorsP) ~= obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.StagnationFactorsP;
        end % function val = get.StagnationFactors(obj)
                
        function val = get.TrafficTotals(obj)
            if numel(obj.TrafficTotalsP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.TrafficTotalsP;
        end % function val = get.TrafficTotals(obj)

        function val = get.TrafficTotalsScaled(obj)
            if numel(obj.TrafficTotalsScaledP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.TrafficTotalsScaledP;
        end % function val = get.TrafficTotalsScaled(obj)
        
        function val = get.EmissionsPM10(obj)
            if numel(obj.EmissionsPM10P) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.EmissionsPM10P;
        end % function val = get.EmissionsPM10(obj)
        
                
        function val = get.EmissionsPM25(obj)
            if numel(obj.EmissionsPM25P) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.EmissionsPM25P;
        end % function val = get.EmissionsPM25(obj)
                
        function val = get.EmissionsNOx(obj)
            if numel(obj.EmissionsNOxP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.EmissionsNOxP;
        end % function val = get.EmissionsNOx(obj)
                
        function val = get.EmissionsNO2(obj)
            if numel(obj.EmissionsNO2P) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.EmissionsNO2P;
        end % function val = get.EmissionsNO2(obj)
                
        function val = get.DispersionCoefficientsA(obj)
            if numel(obj.DispersionCoefficientsAP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.DispersionCoefficientsAP;
        end % function val = get.DispersionCoefficientsA(obj)
                
        function val = get.DispersionCoefficientsB(obj)
            if numel(obj.DispersionCoefficientsBP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.DispersionCoefficientsBP;
        end % function val = get.DispersionCoefficientsB(obj)
                
        function val = get.DispersionCoefficientsC(obj)
            if numel(obj.DispersionCoefficientsCP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.DispersionCoefficientsCP;
        end % function val = get.DispersionCoefficientsC(obj)
                
        function val = get.DispersionCoefficientsAlpha(obj)
            if numel(obj.DispersionCoefficientsAlphaP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.DispersionCoefficientsAlphaP;
        end % function val = get.DispersionCoefficientsAlpha(obj)

        function val = get.XVertices(obj)
            [NNN, ~] = size(obj.XVerticesP);
            if NNN ~= obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.XVerticesP;
        end % function val = get.XVertices(obj)
        
        function val = get.YVertices(obj)
            [NNN, ~] = size(obj.YVerticesP);
            if NNN ~= obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.YVerticesP;
        end % function val = get.YVertices(obj)

        function val = get.ImpactDistances(obj)
            if numel(obj.ImpactDistancesP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.ImpactDistancesP;
        end % function val = get.ImpactDistances(obj)
        
        function val = get.XMins(obj)
            if numel(obj.XMinsP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.XMinsP;
        end % function val = get.XMins(obj)
        
        function val = get.YMins(obj)
            if numel(obj.YMinsP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.YMinsP;
        end % function val = get.YMins(obj)
        
        function val = get.XMaxs(obj)
            if numel(obj.XMaxsP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.XMaxsP;
        end % function val = get.XMaxs(obj)
        
        function val = get.YMaxs(obj)
            if numel(obj.YMaxsP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.YMaxsP;
        end % function val = get.YMaxs(obj)
        
        function val = get.XMinsImpact(obj)
            if numel(obj.XMinsImpactP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.XMinsImpactP;
        end % function val = get.XMinsImpact(obj)
        
        function val = get.YMinsImpact(obj)
            if numel(obj.YMinsImpactP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.YMinsImpactP;
        end % function val = get.YMinsImpact(obj)
        
        function val = get.XMaxsImpact(obj)
            if numel(obj.XMaxsImpactP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.XMaxsImpactP;
        end % function val = get.XMaxsImpact(obj)
        
        function val = get.YMaxsImpact(obj)
            if numel(obj.YMaxsImpactP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.YMaxsImpactP;
        end % function val = get.YMaxsImpact(obj)
        
        function val = get.RoadLengths(obj)
            if numel(obj.RoadLengthsP) ~=obj.NumRoads
                obj.GetRoadParameters
            end
            val = obj.RoadLengthsP;
        end % function val = get.RoadLengths(obj)
        
        function val = get.LongestRoadLength(obj)
            if obj.LongestRoadLengthP == -999
                obj.GetRoadParameters
            end
            val = obj.LongestRoadLengthP;
        end % function val = get.LongestRoadLength(obj)  
        
        function val = get.TrafficContributionsPM10(obj)
            if numel(obj.TrafficContributionsPM10P) == 0
                obj.TrafficContributionsPM10P = [obj.RoadSegments.TrafficContributionsPM10]';
            end
            val = obj.TrafficContributionsPM10P;
        end % function val = get.TrafficContributionsPM10(obj)
        
        function val = get.TrafficContributionsPM25(obj)
            if numel(obj.TrafficContributionsPM25P) == 0
                obj.TrafficContributionsPM25P = [obj.RoadSegments.TrafficContributionsPM25]';
            end
            val = obj.TrafficContributionsPM25P;
        end % function val = get.TrafficContributionsPM25(obj)
        
        function val = get.TrafficContributionsNO2(obj)
            if numel(obj.TrafficContributionsNO2P) == 0
                obj.TrafficContributionsNO2P = [obj.RoadSegments.TrafficContributionsNO2]';
            end
            val = obj.TrafficContributionsNO2P;
        end % function val = get.TrafficContributionsNO2(obj)
        
        function val = get.TrafficContributionsNOx(obj)
            if numel(obj.TrafficContributionsNOxP) == 0
                obj.TrafficContributionsNOxP = [obj.RoadSegments.TrafficContributionsNOx]';
            end
            val = obj.TrafficContributionsNOxP;
        end % function val = get.TrafficContributionsNOx(obj)
        
        function val = get.CalculationDistance(obj)
            % First check, is a Model object defined? 
            if ~isempty(obj.ModelObject)
                % It is. In that case use the value from the model.
                obj.CalculationDistanceP = obj.ModelObject.CalculationDistance;
            end
            val = obj.CalculationDistanceP;
        end % function val = get.CalculationDistance(obj)
        
        function val = get.CalculationDistanceMode(obj)
            % First check, is a Model object defined? 
            if ~isempty(obj.ModelObject)
                % It is. In that case use the value from the model.
                obj.CalculationDistanceModeP = obj.ModelObject.CalculationDistanceMode;
            end
            val = obj.CalculationDistanceModeP;
        end % function val = get.CalculationDistance(obj)
        
        function set.CalculationDistance(obj, val)
            % First check, is a Model object defined?
            if ~isempty(obj.ModelObject)
                % It is. Well is the calculation distance of that object the
                % same as is being specified? If so, then it might be that
                % object doing the setting.
                if ~isequal(val, obj.ModelObject.CalculationDistance)
                    error('SRM1Model:RoadNetwork:SetCalculationDistance:ModelSet', 'CalculationDistance should be set in the road network''s parent SRM1Model object.')
                end
            end
            % And check that the number is not negative.
            if val < 0
                error('SRM1Model:RoadNetwork:SetCalculationDistance:NegativeNumber', 'CalculationDistance must be greater or equal to zero.')
            end
            obj.CalculationDistanceP = val;
            obj.TrafficContributionsPM10P = [];
            obj.TrafficContributionsPM25P = [];
            obj.TrafficContributionsNO2P = [];
            obj.TrafficContributionsNOxP = [];
            %obj.RoadSegments.CalculationDistance(val);
        end % function set.CalculationDistance(obj)
        
        function set.CalculationDistanceMode(obj, val)
            % First check, is a Model object defined?
            if ~isempty(obj.ModelObject)
                % It is. Well is the calculation distance of that object the
                % same as is being specified? If so, then it might be that
                % object doing the setting.
                if ~isequal(val, obj.ModelObject.CalculationDistanceMode)
                    error('SRM1Model:RoadNetwork:SetCalculationDistanceMode:ModelSet', 'CalculationDistanceMode should be set in the road network''s parent SRM1Model object.')
                end
            end
            % And check that the number is not negative.
            if ~ismember(val, obj.CalculationDistanceModeAllowedValues)
                error('SRM1Model:RoadNetwork:SetCalculationDistanceMode:BadValue', 'CalculationDistanceMode must be one of either ''%s'' or ''%s''.', obj.CalculationDistanceModeAllowedValues{1}, obj.CalculationDistanceModeAllowedValues{2})
            end
            obj.CalculationDistanceModeP = val;
            obj.TrafficContributionsPM10P = [];
            obj.TrafficContributionsPM25P = [];
            obj.TrafficContributionsNO2P = [];
            obj.TrafficContributionsNOxP = [];
            %obj.RoadSegments.CalculationDistance(val);
        end % function set.CalculationDistance(obj)
        
        %% Setters
        function set.ChangesMadeMinor(obj, val)
            obj.ChangesMadeMinorP = val;
            if ~isempty(obj.ModelObject)
                obj.ModelObject.RoadNetworkChangedMinor = val;
                obj.TrafficContributionsPM10P = [];
                obj.TrafficContributionsPM25P = [];
                obj.TrafficContributionsNO2P = [];
                obj.TrafficContributionsNOxP = [];
            end
        end % function set.ChangesMadeMinor(obj, val)
        
        function set.ChangesMadeMajor(obj, val)
            obj.ResetRoadProperties;
            obj.ChangesMadeMajorP = val;
            if ~isempty(obj.ModelObject)
                obj.ModelObject.RoadNetworkChangedMajor = val;
            end
        end % function set.ChangesMadeMajor(obj, val)
        
        function set.RoadSegments(obj, val)
            if ~isequal(val, obj.RoadSegmentsP)
                obj.RoadSegmentsP = val;
                obj.GetRoadParameters;
            end
        end % function set.RoadSegments(obj, val)
        
        function set.EmissionFactors(obj, val)
            obj.EmissionFactorsP = val;
            % Set all the road segments too.
            for RI = obj.RoadSegments'
                try
                    RI.EmissionFactors = val;
                catch err
                    disp(err)
                    rethrow(err)
                    % A thought. Might only be neccesary/appropriate for RI
                    % == 1.
                    % obj.EmissionFactorsP = Pre;
                end
            end
        end % function set.EmissionFactors(obj, val)
        
        function SetVehicleScaling(obj, Vehs, Scales, varargin)
            Options.Force = false;
            Options = checkArguments(Options, varargin);
            if isa(Vehs, 'cell')
                if numel(Vehs) ~= numel(Scales)
                    error('SRM1:RoadNetwork:SetVehicleScaling:NumScalesNotNumVehs', 'The number of assigned vehicles must equal the number of assigned scales.')
                end
            else
                Vehs = {Vehs};
            end
            % Check that specified vehicles are allowed.
            for VehI = 1:numel(Vehs)
                Veh = Vehs{VehI};
                isM = ismember(Veh, obj.VehicleBreakdown);
                if ~isM
                    error('SRM1:RoadNetwork:SetVehicleScaling:BadVehicle', 'No vehicle ''%s'' is present.', Veh)
                end
            end
            AllIdentical = obj.VehicleScaling_AllIdentical;
            if sum(AllIdentical) == numel(AllIdentical)
                Do = 1;
            else
                % There are some differences for some vehicle types.
                if Options.Force
                    Do = 1;
                else
                    % See if the differences are for any of the requested
                    % vehicles.
                    for VehI = 1:numel(Vehs)
                        Veh = Vehs{VehI};
                        [~, Wh] = ismember(Veh, obj.VehicleBreakdown);
                        % Check that all are identical for this vehicle.
                        if AllIdentical(Wh)
                            % No probs with that vehicle.
                            Do = 1;
                        else
                            Question = sprintf(['The scaling for ''%s'', ', ...
                                'and perhaps other vehicles, is currently ', ...
                                'not identical between all road segments in ', ...
                                'this road network. Are you sure that you ', ...
                                'wish to make the scaling identical for the designated vehicles for all ', ...
                                'roads in the road network?'], Veh);
                            Ans = questdlg(Question);
                            if isequal(Ans, 'Yes')
                                Do = 1;
                            else
                                Do = 0;
                            end
                        end
                    end
                end
            end
            if Do
                for RS = obj.RoadSegments'
                    for VehI = 1:numel(Vehs)
                        Veh = Vehs{VehI};
                        RS.VehicleScaling.(Veh) = Scales(VehI);
                    end
                end
            end
        end % function SetVehicleScaling(obj, Veh, Scale)
        
        %% Other functions
%         function NewObj = NetworkSubset(obj, Indices)
% 
%             RoadSegmentsAll = obj.RoadSegments;
%             RoadSegmentsSubSet = RoadSegmentsAll(Indices);
%             
%             NewObj = SRM1.RoadNetwork('SourceShapeFile', obj.SourceShapeFile, ...
%                                       'SubSetOf', obj, ...
%                                       'RoadSegments', RoadSegmentsSubSet, ...
%                                       'EmissionFactors', obj.EmissionFactors, ...
%                                       'VehicleBreakdown', obj.VehicleBreakdown);
% 
%                                   
%                                   
%             error('a')
%  
%             
%             NewObj.RoadSegmentsP = RoadSegmentsSubSet;
%             
%             NewObj.TreeFactorsP = obj.TreeFactorsP(Indices);
%             NewObj.EmissionsPM10P = obj.EmissionsPM10P(Indices);
%             NewObj.EmissionsPM25P = obj.EmissionsPM25P(Indices);
%             NewObj.EmissionsNOxP = obj.EmissionsNOxP(Indices);
%             NewObj.EmissionsNO2P = obj.EmissionsNO2P(Indices);
%             NewObj.DispersionCoefficientsAP = obj.DispersionCoefficientsAP(Indices);
%             NewObj.DispersionCoefficientsBP = obj.DispersionCoefficientsBP(Indices);
%             NewObj.DispersionCoefficientsCP = obj.DispersionCoefficientsCP(Indices);
%             NewObj.DispersionCoefficientsAlphaP = obj.DispersionCoefficientsAlphaP(Indices);
%             NewObj.XVerticesP = obj.XVerticesP(Indices);
%             NewObj.YVerticesP = obj.YVerticesP(Indices);
%             NewObj.XMinsP = obj.XMinsP(Indices);
%             NewObj.XMinsImpactP = obj.XMinsImpactP(Indices);
%             NewObj.XMaxsP = obj.XMaxsP(Indices);
%             NewObj.XMaxsImpactP = obj.XMaxsImpactP(Indices);
%             NewObj.YMinsP = obj.YMinsP(Indices);
%             NewObj.YMinsImpactP = obj.YMinsImpactP(Indices);
%             NewObj.YMaxsP = obj.YMaxsP(Indices);
%             NewObj.YMaxsImpactP = obj.YMaxsImpactP(Indices);
%             NewObj.RoadLengthsP = obj.RoadLengthsP(Indices);
%             NewObj.LongestRoadLengthP = max(NewObj.RoadLengthsP);
%             
%             %NewObj.ResetRoadProperties;
%         end % function NewObj = NetworkSubset(obj, Indices)
            
        function [Int, EndV1, EndV2] = RoadIntersect(obj, N1, N2, varargin)
            % Tests to see if the road segment number N1 intersects the
            % road segment N2 at either end.
            Options = struct('Closeness', 0.1);
            Options = checkArguments(Options, varargin);
            Closeness = Options.Closeness;
            
            Rd1 = obj.RoadSegments(N1);
            Vs1 = Rd1.Vertices;
            [NumV1s, ~] = size(Vs1);
            End11 = Vs1(1, :);
            End1e = Vs1(NumV1s, :);
            Rd2 = obj.RoadSegments(N2);
            Vs2 = Rd2.Vertices;
            [NumV2s, ~] = size(Vs2);
            End21 = Vs2(1, :);
            End2e = Vs2(NumV2s, :);
            if distancePoints(End11, End21) < Closeness
                Int = true;
                EndV1 = 1; EndV2 = 1;
            elseif distancePoints(End11, End2e) < Closeness
                Int = true;
                EndV1 = 1; EndV2 = NumV2s; 
            elseif distancePoints(End1e, End21) < Closeness
                Int = true;
                EndV1 = NumV1s; EndV2 = 1;
            elseif distancePoints(End1e, End2e) < Closeness
                Int = true;
                EndV1 = NumV1s; EndV2 = NumV2s; 
            else
                Int = false;
                EndV1 = nan; EndV2 = nan;
            end
        end % function Int = RoadIntersect(N1, N2, varargin)
        
        function Indices = RoadsNearBy(obj, Pt, varargin)
            % Formerly [NewObj, Indices] = RoadsNearBy(obj, Pt)
            % Returns a new SRM1.RoadNetwork object composed of the road
            % segments that are within the impact distance of a point. The
            % roads will be sorted for distance from the point.
            
            X = Pt(1); Y = Pt(2);
            if numel(varargin)
                % Assume a different distance has been specified. So that
                % instead of judging against the impact distance we judge
                % against this set distance.
                Distance = varargin{1};
                XMinsImpact_ = obj.XMins - Distance;
                YMinsImpact_ = obj.YMins - Distance;
                XMaxsImpact_ = obj.XMaxs + Distance;
                YMaxsImpact_ = obj.YMaxs + Distance;
                IDs = Distance*ones(size(obj.ImpactDistances));
            else
                XMinsImpact_ = obj.XMinsImpact; XMaxsImpact_ = obj.XMaxsImpact;
                YMinsImpact_ = obj.YMinsImpact; YMaxsImpact_ = obj.YMaxsImpact;
                IDs = obj.ImpactDistances;
            end
            % Find the roads whose impact bounding boxes enclose the point.
            CloseX = and(XMinsImpact_ <= X, XMaxsImpact_ >= X);
            CloseY = and(YMinsImpact_ <= Y, YMaxsImpact_ >= Y);
            Close = and(CloseX, CloseY);
            CloseRoadIs = find(Close);
            % Now check and see if the road is within the calculation
            % distance.
            GotOne = false;
            XVVV = obj.XVertices;
            YVVV = obj.YVertices;
            Ds = [];
            DIs = [];
            %Ds = nan(1, numel(CloseRoadIs)); Di = 1
            for RdI = CloseRoadIs'
                tic
                XVs = XVVV(RdI, :);
                YVs = YVVV(RdI, :);
                ID = IDs(RdI);
                XVs = XVs(~isnan(XVs));
                YVs = YVs(~isnan(YVs));
                Vs = [XVs', YVs'];
                D = distancePointPolyline(Pt, Vs);
                if D <= ID
                    GotOne = true;
                    Ds(end+1) = D; %#ok<AGROW>
                    DIs(end+1) = RdI; %#ok<AGROW>
                end
            end
            if ~GotOne
                Indices = [];
            else
                [~, SortI] = sort(Ds);
                Indices = DIs(SortI);
            end
        end % function Segments = RoadsNearBy(Pt, obj)
        
        function [AcceptedIndices, CloseEnoughRoadsIndices, Reasons, Issues] = RoadsImpacting(obj, Pt, varargin)
            % Formerly [NewObj, CloseEnoughRoads, Reasons, Issues, Indices] = RoadsImpacting(obj, Pt)
            % Return the subset of roads which have an impact on the
            % calculation point. This should include the effects of roads
            % meeting at intersections, and of dual carriagways and roads
            % passing over one another, etc. But should avoid double
            % counting when a calculation point happens to sit beside the
            % intersection between segments of the same road.
            % Will also remove roads with no traffic counts.
            
            Issues = false;
            
            if numel(varargin)
                % Assume a different distance has been specified. So that
                % instead of judging against the impact distance we judge
                % against this set distance.
                Distance = varargin{1};
                CloseEnoughRoadsIndices = obj.RoadsNearBy(Pt, Distance);
            else
                % Return the subset of roads which are within their own
                % impact distance of the calculation point.
                CloseEnoughRoadsIndices = obj.RoadsNearBy(Pt);
            end
            if isempty(CloseEnoughRoadsIndices)
                Reasons = [];
                AcceptedIndices = [];
                return
            end
            
            NumClose = numel(CloseEnoughRoadsIndices);
            Reasons = nan(NumClose, 1);
            % Find the closest road with traffic on it.
            IncludeRoadNumber = 0;
            for TCI = 1:NumClose
                Index = CloseEnoughRoadsIndices(TCI);
                TC = obj.RoadSegments(Index).TrafficTotal;
                if TC == 0
                    Reasons(TCI) = 5;
                else
                    Reasons(TCI) = 0; %'Included';
                    IncludeRoadNumber = 1;
                    AcceptedIndices = Index;
                    FirstTest = TCI+1;
                    break
                end
            end
            if IncludeRoadNumber == 0
                % Haven't found any with traffic data.
                %NewObj = SRM1.RoadNetwork.empty;
                AcceptedIndices = [];
                return
            end
            % And check the others for applicability.
            if NumClose >= FirstTest
                for RdI = FirstTest:NumClose
                    Index = CloseEnoughRoadsIndices(RdI);
                    LeaveIt = false;
                    TestRoad = obj.RoadSegments(Index);
                    TestCounts = TestRoad.TrafficTotal;
                    if TestCounts == 0
                        Reasons(RdI) = 5;
                        LeaveIt = true; %#ok<NASGU>
                        continue
                    end
                    % Test it against all of the already selected roads.
                    NoIntersect = true;
                    for RdJ = 1:numel(AcceptedIndices)
                        PreRoad = obj.RoadSegments(AcceptedIndices(RdJ));
                        PreCounts = PreRoad.TrafficTotal;
                        % Do they intersect?
                        [Intersect, EndVI, EndVJ] = obj.RoadIntersect(Index, IncludeRoadNumber(RdJ));
                        if Intersect
                            NoIntersect = false;
                            % They do! Do the parts that intersect run paralel to one another?
                            if EndVI == 1
                                EndSegI = [TestRoad.Vertices(2, 1) - TestRoad.Vertices(1, 1), ...
                                           TestRoad.Vertices(2, 2) - TestRoad.Vertices(1, 2), ...
                                           0];
                            else
                                EndSegI = [TestRoad.Vertices(end-1, 1) - TestRoad.Vertices(end, 1), ...
                                           TestRoad.Vertices(end-1, 2) - TestRoad.Vertices(end, 2), ...
                                           0];
                            end
                            if EndVJ == 1
                                EndSegJ = [PreRoad.Vertices(2, 1) - PreRoad.Vertices(1, 1), ...
                                           PreRoad.Vertices(2, 2) - PreRoad.Vertices(1, 2), ...
                                           0];
                            else
                                EndSegJ = [PreRoad.Vertices(end-1, 1) - PreRoad.Vertices(end, 1), ...
                                           PreRoad.Vertices(end-1, 2) - PreRoad.Vertices(end, 2), ...
                                           0];
                            end
                            
                            % Normalize to unit length.
                            EndSegI = EndSegI/sqrt(sum(EndSegI.*EndSegI));
                            EndSegJ = EndSegJ/sqrt(sum(EndSegJ.*EndSegJ));
                            AngleBetween = acosd(dot(EndSegI, EndSegJ));
                            if AngleBetween < 0
                                warning('Angle Between = %06.2f', AngleBetween)
                            elseif AngleBetween > 180
                                warning('Angle Between = %06.2f', AngleBetween)
                            end
                            if AngleBetween > 160
                                % Angle is close to a straight
                                % continuation of a road that is already
                                % included, so ignore it even if the
                                % traffic counts are different.
                                Reasons(RdI) = 1;
                                LeaveIt = true;
                                break
                            elseif AngleBetween > 100
                                if isequal(TestCounts, PreCounts)
                                    % Road counts are the same, and the
                                    % angle is obtuse, so assume it's a
                                    % continuation of the same road and
                                    % ignore.
                                    Reasons(RdI) = 2;
                                    LeaveIt = true;
                                    break
                                end
                            end    
                        end
                        if NoIntersect
                            % The road does not intersect any of the already
                            % selected roads. See what type of road it is.
                            if ~isequal(TestRoad.RoadClass, 'Not A Canyon')
                                % It's a canyon, so the emissions from it
                                % are unlikely to have escaped over the canyon
                                % to wherever this point is.
                                Reasons(RdI) = 3;
                                LeaveIt = true;
                                break
                            else
                                % The test street is not a canyon, but is the
                                % road closest to the calculation point a
                                % canyon?
                                if ~isequal(obj.RoadSegments(AcceptedIndices(1)).RoadClass, 'Not A Canyon')
                                    % It is.
                                    Reasons(RdI) = 4;
                                    LeaveIt = true;
                                    break
                                end
                            end
                        end
                    end
                    if ~LeaveIt
                        IncludeRoadNumber(end+1) = RdI; %#ok<AGROW>
                        Reasons(RdI) = 0;
                        AcceptedIndices(end+1) = Index; %#ok<AGROW>
                    end
                end
            end
        end % function RoadsImpacting(Pt, obj)
        
        function Identical = CheckScalingIdentical(obj)
            fprintf('Checking vehicle scalings are identical across road network.\n')
            VS1 = obj.RoadSegments(1).VehicleScaling;
            Identical = ones(1, numel(obj.VehicleBreakdown));
            VIs = 1:numel(obj.VehicleBreakdown);
            for Ri = 2:obj.NumRoads
                VSCheck = obj.RoadSegments(Ri).VehicleScaling;
                if ~isequal(VS1, VSCheck)
                    for VI = VIs
                        V = obj.VehicleBreakdown{VI};
                        if ~isequal(VS1.(V), VSCheck.(V))
                            Identical(VI) = 0;
                        end
                    end
                    % If all are different, then no point checking any
                    % other roads.
                    if sum(Identical) == 0
                        break
                    end
                    % May as well not check those vehicles that have
                    % already been found to be different.
                    VIs(Identical == 0) = [];
                    Identical(Identical == 0) = [];
                end
            end
            fprintf('    Done.\n')
        end % function Identical = CheckScalingIdentical(obj)
        
        function ChangeValue(obj, In)
            % Raised by a child road segment.
            Field = In{1};
            ID = In{2};
            switch Field
                case 'TrafficTotalsScaled'
                    TT = obj.RoadSegments(ID).TrafficTotalScaled;
                    obj.TrafficTotalsScaledP(ID) = TT;
                case 'Tree'
                    TF = obj.RoadSegments(ID).TreeFactor;
                    obj.TreeFactorsP(ID) = TF;
                    ChangeIndices = find(obj.ModelObject.PointRoadsImpacting == ID);
                    obj.ModelObject.SetPointRoadArrays('Tree', ChangeIndices, TF) %#ok<FNDSB>
                case 'Emissions'
                    Ems = obj.RoadSegments(ID).Emissions;
                    obj.EmissionsPM10P(ID) = Ems.PM10;
                    obj.EmissionsPM25P(ID) = Ems.PM25;
                    obj.EmissionsNO2P(ID) = Ems.NO2;
                    obj.EmissionsNOxP(ID) = Ems.NOx;
                    %obj.ModelObject.PointRoadsImpacting
                    ChangeIndices = find(obj.ModelObject.PointRoadsImpacting == ID);
                    obj.ModelObject.SetPointRoadArrays('EmPM10', ChangeIndices, Ems.PM10)
                    obj.ModelObject.SetPointRoadArrays('EmPM25', ChangeIndices, Ems.PM25)
                    obj.ModelObject.SetPointRoadArrays('EmNO2', ChangeIndices, Ems.NO2)
                    obj.ModelObject.SetPointRoadArrays('EmNOx', ChangeIndices, Ems.NOx)
                case 'RoadClass'
                    [~, RoadClassNum] = ismember(obj.RoadSegments(ID).RoadClass, {'Wide Canyon', 'Narrow Canyon', 'One Sided Canyon', 'Not A Canyon'});
                    obj.ModelObject.ChangeRoadClass(ID);
                    obj.RoadClassesP(ID) = RoadClassNum;
                    DispCoeff = obj.RoadSegments(ID).DispersionCoefficients;
                    obj.DispersionCoefficientsAP(ID) = DispCoeff.A;
                    obj.DispersionCoefficientsBP(ID) = DispCoeff.B;
                    obj.DispersionCoefficientsCP(ID) = DispCoeff.C;
                    obj.DispersionCoefficientsAlphaP(ID) = DispCoeff.Alpha;
                    obj.ImpactDistancesP(ID) = obj.RoadSegments(ID).ImpactDistance;
                    
                    
                    warning('WHY DOES THIS RESET ALL ROAD TRAFFIC CONTRIBUTIONS???')
                otherwise
                    error('SRM1:RoadNetwork:ChangeValue:BadField', 'Cannot change field ''%s''.', Field)
            end
            % Wally
            obj.ChangesMadeMinor = 1;
        end % function ChangeValue(Field, Value)
        
        function ResetRoadProperties(obj)
            obj.TreeFactorsP = [];
            obj.TrafficTotalsP = [];
            obj.TrafficTotalsScaledP = [];
            obj.EmissionsPM10P = [];
            obj.EmissionsPM25P = [];
            obj.EmissionsNOxP = [];
            obj.EmissionsNO2P = [];
            obj.DispersionCoefficientsAP = [];
            obj.DispersionCoefficientsBP = [];
            obj.DispersionCoefficientsCP = [];
            obj.DispersionCoefficientsAlphaP = [];
            obj.TrafficContributionsPM10P = [];
            obj.TrafficContributionsPM25P = [];
            obj.TrafficContributionsNO2P = [];
            obj.TrafficContributionsNOxP = [];
            obj.XVerticesP = [];
            obj.YVerticesP = [];
            obj.XMinsP = [];
            obj.XMinsImpactP = [];
            obj.XMaxsP = [];
            obj.XMaxsImpactP = [];
            obj.YMinsP = [];
            obj.YMinsImpactP = [];
            obj.YMaxsP = [];
            obj.YMaxsImpactP = [];
            obj.RoadLengthsP = [];
            obj.LongestRoadLengthP = -999;           
        end % function ResetRoadProperties(obj)
        
        function GetRoadParameters(obj)
            fprintf('Getting road parameters. This should only be neccesary if the RoadSegments have been added or removed, or if an individual road segment vertices or road class has been altered.''s\n')
            NumFeatures = obj.NumRoads;
            wb = waitbar(0, sprintf('Getting properties for road %d of %d.', 1, NumFeatures), ...
                'CreateCancelBtn', ...
                'setappdata(gcbf, ''canceling'',1)');
            setappdata(wb, 'canceling', 0)
            XVertices_ = nan(NumFeatures, 10);
            YVertices_ = nan(NumFeatures, 10);
            ImpactDist_ = nan(NumFeatures, 1);
            TrafficTotals_ = nan(NumFeatures, 1);
            TrafficTotalsScaled_ = nan(NumFeatures, 1);
            EmissionsPM10_ = nan(NumFeatures, 1);
            EmissionsPM25_ = nan(NumFeatures, 1);
            EmissionsNOx_ = nan(NumFeatures, 1);
            EmissionsNO2_ = nan(NumFeatures, 1);
            DispersionCoefficientsA_ = nan(NumFeatures, 1);
            DispersionCoefficientsB_ = nan(NumFeatures, 1);
            DispersionCoefficientsC_ = nan(NumFeatures, 1);
            DispersionCoefficientsAlpha_ = nan(NumFeatures, 1);
            TreeFactors_ = nan(NumFeatures, 1);
            RoadLengths_ = nan(NumFeatures, 1);
            RoadClasses_ = nan(NumFeatures, 1);
            SpeedClasses_ = nan(NumFeatures, 1);
            Speeds_ = nan(NumFeatures, 1);
            StagnationFactors_ = nan(NumFeatures, 1);
            LongestRoadLength_ = -999;
            for Ri = 1:NumFeatures
                if getappdata(wb, 'canceling')
                    delete(wb)
                    obj.ResetRoadProperties;
                    return
                end
                waitbar(Ri/NumFeatures, wb, sprintf('Getting properties for road %d of %d.', Ri, NumFeatures))
                
                % For each road segment, get the bounding boxes, and
                % assign the dispersion factors and emission factors.
                Rd = obj.RoadSegments(Ri);
                if isempty(obj.SubSetOf)
                    % Only assign a parent if that field is empty, to
                    % ensure that I don't reassign parent values within
                    % a subset (these are handle classes).
                    obj.RoadSegmentsP(Ri).ParentRoadNetwork = obj;
                else
                    obj.RoadSegmentsP(Ri).ParentRoadNetwork = obj.SubSetOf;
                end
                VVV = Rd.Vertices;
                [RoadLength, ~] = size(VVV);
                if RoadLength > LongestRoadLength_
                    LongestRoadLength_ = RoadLength;
                end
                RoadLengths_(Ri) = RoadLength;
                
                VVV(VVV == 0) = -987654321.123;     % Because as arrays grow they are automatically padded with zeros.
                XVertices_(Ri, 1:RoadLength) = VVV(:, 1);
                YVertices_(Ri, 1:RoadLength) = VVV(:, 2);
                ImpactDist_(Ri) = Rd.ImpactDistance;
                %BB = Rd.BoundingBox;
                %XMins_(Ri) = BB(1, 1);
                %YMins_(Ri) = BB(1, 2);
                %XMaxs_(Ri) = BB(2, 1);
                %YMaxs_(Ri) = BB(2, 2);
                %BB = Rd.ImpactBoundingBox;
                %XMinsImpact_(Ri) = BB(1, 1);
                %YMinsImpact_(Ri) = BB(1, 2);
                %XMaxsImpact_(Ri) = BB(2, 1);
                %YMaxsImpact_(Ri) = BB(2, 2);
                TrafficTotals_(Ri) = Rd.TrafficTotal;
                TrafficTotalsScaled_(Ri) = Rd.TrafficTotalScaled;
                Ems = Rd.Emissions;
                EmissionsPM10_(Ri) = Ems.PM10;
                EmissionsPM25_(Ri) = Ems.PM25;
                EmissionsNO2_(Ri) = Ems.NO2;
                EmissionsNOx_(Ri) = Ems.NOx;
                Disp = Rd.DispersionCoefficients;
                DispersionCoefficientsA_(Ri) = Disp.A;
                DispersionCoefficientsB_(Ri) = Disp.B;
                DispersionCoefficientsC_(Ri) = Disp.C;
                DispersionCoefficientsAlpha_(Ri) = Disp.Alpha;
                TreeFactors_(Ri) = Rd.TreeFactor;
                [~, RoadClasses_(Ri)] = ismember(Rd.RoadClass, {'Wide Canyon', 'Narrow Canyon', 'One Sided Canyon', 'Not A Canyon'});
                [~, SpeedClasses_(Ri)] = ismember(Rd.SpeedClass, {'Stagnated', 'Normal', 'Smooth', 'LargeRoad'});
                StagnationFactors_(Ri) = Rd.Stagnation;
                Speeds_(Ri) = Rd.Speed;
            end
            obj.RoadLengthsP = RoadLengths_;
            obj.LongestRoadLengthP = LongestRoadLength_;
            XVVV = XVertices_(:, 1:LongestRoadLength_);
            XVVV(XVVV == 0) = nan;
            XVVV(XVVV == -987654321.123) = 0;
            YVVV = YVertices_(:, 1:LongestRoadLength_);
            YVVV(YVVV == 0) = nan;
            YVVV(YVVV == -987654321.123) = 0;
            obj.XVerticesP = XVVV;
            obj.YVerticesP = YVVV;
            obj.ImpactDistancesP = ImpactDist_;
            obj.XMinsP = min(XVVV, [], 2);
            obj.YMinsP = min(YVVV, [], 2);
            obj.XMaxsP = max(XVVV, [], 2);
            obj.YMaxsP = max(YVVV, [], 2);
            obj.XMinsImpactP = obj.XMinsP - ImpactDist_;
            obj.YMinsImpactP = obj.YMinsP - ImpactDist_;
            obj.XMaxsImpactP = obj.XMaxsP + ImpactDist_;
            obj.YMaxsImpactP = obj.YMaxsP + ImpactDist_;
            obj.TrafficTotalsP = TrafficTotals_;
            obj.TrafficTotalsScaledP = TrafficTotalsScaled_;
            obj.EmissionsPM10P = EmissionsPM10_;
            obj.EmissionsPM25P = EmissionsPM25_;
            obj.EmissionsNO2P = EmissionsNO2_;
            obj.EmissionsNOxP = EmissionsNOx_;
            obj.DispersionCoefficientsAP = DispersionCoefficientsA_;
            obj.DispersionCoefficientsBP = DispersionCoefficientsB_;
            obj.DispersionCoefficientsCP = DispersionCoefficientsC_;
            obj.DispersionCoefficientsAlphaP = DispersionCoefficientsAlpha_;
            obj.TreeFactorsP = TreeFactors_;
            obj.RoadClassesP = RoadClasses_;
            obj.SpeedClassesP = SpeedClasses_;
            obj.StagnationFactorsP = StagnationFactors_;
            obj.SpeedsP = Speeds_;
            delete(wb)
        end % function GetRoadParameters(obj)
        
        function ResetTrafficContributions(obj)
            obj.TrafficContributionsPM10P = [];
            obj.TrafficContributionsPM25P = [];
            obj.TrafficContributionsNO2P = [];
            obj.TrafficContributionsNOxP = [];
        end % function ResetTrafficContributions(obj)
    end % methods
    
    %%
    methods(Static)
        function obj = CreateFromShapeFile(filename, varargin)
            
            Options = struct('EmissionFactors', 'Default', ...
                             'DispersionCoefficients', 'Default');
            Options = checkArguments(Options, varargin);
            % Read the shape file.
            S = shaperead(filename);
            NumFeatures = numel(S);
            for i = 1:NumFeatures
                R = S(i);
                if ~isequal(R.Geometry, 'Line')
                    error('SRMI1RoadNetwork:NotLine', 'Features should have line geometry.')
                end
                RoadSegment = SRM1.RoadSegment('Attributes', R, 'Number', i, 'EmissionFactors', Options.EmissionFactors);
                if i == 1
                    RoadSegments_ = repmat(RoadSegment, NumFeatures, 1);
                    VBD = RoadSegment.VehicleBreakdown;
                else
                    VBD_ = RoadSegment.VehicleBreakdown;
                    if ~isequal(VBD, VBD_)
                        error('SRM1:RoadNetwork:CreateFromShapeFile:NotSameVeh', 'The vehicle breakdown for all road segments must be the same.')
                    end
                    RoadSegments_(i) = RoadSegment;
                end
            end
            obj = SRM1.RoadNetwork('SourceShapeFile', filename, ...
                                   'RoadSegments', RoadSegments_, ...
                                   'EmissionFactors', Options.EmissionFactors, ...
                                   'DispersionCoefficients', Options.DispersionCoefficients, ...
                                   'VehicleBreakdown', VBD);
        end % function obj = CreateFromShapeFile(filename, varargin)
    end % methods(Static)
end % classdef RoadNetwork < handle