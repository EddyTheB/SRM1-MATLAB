RoadsShp = '\\sepa-fp-01\DIR SCIENCE\EQ\Oceanmet\Projects\air\CAFS\Glasgow\dataForDutchModel\ProcessedData\glasgowRoadsMerged.shp';
PointsShp = '\\sepa-fp-01\DIR SCIENCE\EQ\Oceanmet\Projects\air\CAFS\Glasgow\dataForDutchModel\ProcessedData\roadside_points.shp';

Model = SRM1Model;
Model.ImportCalculationPoints(PointsShp);
Model.AverageWindSpeed = 4;
Model.BackgroundO3 = 44;
Model.BackgroundPM10 = 12;
Model.BackgroundPM25 = 9;
Model.BackgroundNO2 = 21;
Model.BackgroundNOx = 36;
Model.ImportRoadNetwork(RoadsShp)
%Model.EmissionFactorsName = 'Dutch';