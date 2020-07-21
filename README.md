# H2O AI PowerShell Module
This PowerShell Module is a simple wrapper for a series of POST requests to the [H2O AI](https://www.h2o.ai/) Open Source Platform Server. 

[![PSGallery Version](https://img.shields.io/powershellgallery/v/H2OAI.svg?style=flat&logo=powershell&label=PSGallery%20Version)](https://www.powershellgallery.com/packages/H2OAI) [![PSGallery Downloads](https://img.shields.io/powershellgallery/dt/H2OAI.svg?style=flat&logo=powershell&label=PSGallery%20Downloads)](https://www.powershellgallery.com/packages/H2OAI)

It is based off the work of Tome Tanasovski as detailed in his [blog post - H2o – Machine Learning with PowerShell](https://powertoe.wordpress.com/2017/10/23/h2o-machine-learning-with-powershell/)

It contains three cmdlets of note for using the module;
* Start-H2O (Start the H2O AI Server)
* Stop-H2O (Stop the H2O AI Server)
* Get-H2OPrediction (Get a Prediction using H2O AI)

[Available in the PowerShell Gallery](https://www.powershellgallery.com/packages/H2OAI)

[Associated Blogpost](https://blog.darrenjrobinson.com/h2o-ai-powershell-module/)

## Install
Install direct from the PowerShell Gallery (Powershell 5.1 and above)
```
install-module -name H2OAI
```

## H2O AI Algorithms
[H2O AI Algorithms](http://docs.h2o.ai/h2o/latest-stable/h2o-docs/data-science.html)

The H2O AI PowerShell Module will accept the following algorithms with Get-H2OPrediction. Your Training and Prediction data will need to be of the appropriate type for the algorithm to work. 

**Note** only GLM, GBM and DeepLearning have had any level of testing;
- 'glm', 'gbm', '"glrm', 'aggregator', 'deeplearning', 'drf', 'isolationforest', 'kmeans', 'naivebayes', 'pca', 'targetencoder', 'word2vec'

## Prerequsites
Java SE Runtime Environment

I'm currently running [Java version "1.8.0_251"](https://www.oracle.com/java/technologies/javase/8u251-relnotes.html).

```
PS C:\Users\darrenjrobinson> java -version
java version "1.8.0_251"
Java(TM) SE Runtime Environment (build 1.8.0_251-b08)
Java HotSpot(TM) 64-Bit Server VM (build 25.251-b08, mixed mode)
```

## Download H2O AI
[Download H2O AI](https://h2o-release.s3.amazonaws.com/h2o/rel-weierstrass/7/index.html)
Extract to the local host (e.g. c:\h2o)

**Note** H2O AI is currently a ~240Mb download (version 3.14.0.7). Uncompressed it is ~244Mb.

## Start H2OAI
Import the H2O AI PowerShell Module and start H2O AI.

```
# Path to h2o.jar
$dir = "C:\H2O\h2o-3.14.0.7"
Start-H2o -H2oPath "$($dir)\h2o.jar"

```

# Import Training Data, Build a Model and make a Prediction
Get-H2OPrediction is an all in one cmdlet to make using it super simple. 

Pass Get-H2OPrediction with;
* a dataset
* a model algorithm
* a data split (defaults to 85% Train 15% Test)
* data to make a prediction from and 
* the column to predict 

The default URL for the H2O AI Server is http://localhost:54321 

**Note** The Predict Column name is case sensitive to what is in your dataset. If the dataset has the column heading as 'class' then you call Get-H2OPrediction with -predictColumn **Class** it will FAIL.

```
Get-H2OPrediction
    <#
.SYNOPSIS
    Get an H2O Prediction for a dataset and a sample data request

.DESCRIPTION
    Get an H2O Prediction for a dataset and a sample data request

.PARAMETER url
    H2O URL 
    default: "http://localhost:54321/3/{0}"

.PARAMETER dataset
    H2O Dataset to build model from

.PARAMETER predictData
    Data to build a prediction for

.PARAMETER predictColumn
    Column to provide prediction on

.PARAMETER modelAlgorithm
    Algorithm to build H2O model 
    default: 'glm'

.PARAMETER modelSplit
    Split of Model Dataset between Train and Test
    e.g ".85,.15" 

.EXAMPLE
    Get-H2OPrediction -url "http://localhost:54321/3/{0}" -dataset "c:\Data\dataSet.csv" -predictData = "c:\Data\predictDataSet.csv" -modelAlgorithm = 'glm' -modelSplit = ".85,.15"

#>
```

## Iris Example
Below shows using Tome's the [Iris example](https://powertoe.wordpress.com/2017/10/23/h2o-machine-learning-with-powershell/) with the module.

```
# Default H2O AI Server running locally via Start-H2O
$url = "http://localhost:54321/3/{0}"
# Neural net algorithm for determining Iris type 
$modelAlgorithm = 'deeplearning'

# Get Iris Training data and put on the local filesystem
Invoke-RestMethod -Method Get 'https://raw.githubusercontent.com/DarrenCook/h2o/bk/datasets/iris_wheader.csv' | out-file ./iris_wheader.csv 

# Prediction Column
$predictValues = 'class'

# Data to make prediction from stored as a CSV on the local filesystem
@"
sepal_len, sepal_wid, petal_len, petal_wid
5.1,3.5,1.4,0.15
"@ | out-file -encoding ASCII ./iris_predict.csv

# Send to H2O AI and get prediction 
$dataPath = (Get-ChildItem ./iris_predict.csv).DirectoryName

$result = $null 
$result = Get-H2OPrediction -url $url -dataset "$($dataPath)/iris_wheader.csv" -predictData "$($dataPath)/iris_predict.csv" -modelAlgorithm $modelAlgorithm -modelSplit ".85,.15" -predictColumn $predictValues
$result.prediction | Format-Table

```

### Output 

```
label           data
-----           ----
predict         {0}
Iris-setosa     {0.999969054518561}
Iris-versicolor {3.09454814387964E-05}
Iris-virginica  {2.15784441455808E-28}
```

## Time Series Example
Train a [Genearlised Data Model](http://docs.h2o.ai/h2o/latest-stable/h2o-docs/data-science/glm.html) with a time series dataset with a 85% to 15% split for Train and Test, and predict the next Close value. 

### Example DataSet
$sourceData | Select-Object -First 10 | Format-Table 

```
Open High Close Low  Volume Date
---- ---- ----- ---  ------ ----
3.68 3.8  3.74  3.68 50208  23-01-2017
3.74 3.75 3.75  3.66 47972  24-01-2017
3.75 3.8  3.8   3.73 33952  25-01-2017
3.8  3.8  3.79  3.77 32822  27-01-2017
3.8  3.8  3.73  3.68 21552  30-01-2017
3.75 3.75 3.65  3.6  50763  31-01-2017
3.69 3.69 3.64  3.61 59377  01-02-2017
3.64 3.66 3.55  3.51 120869 02-02-2017
3.64 3.66 3.49  3.49 75814  03-02-2017
3.49 3.54 3.44  3.43 86494  06-02-2017
```

```
# Linear Regression Model 
$modelAlgorithm = 'glm'

# Time Series Data
$dataCSV = "C:\Users\darrenjrobinson\Dropbox\Kloud\Projects\MLDoctaFileServer\data\A2B-AX-3y.csv"
$sourceData = Import-Csv $dataCSV

# Last Record as Prediction data
$dataPredict = Import-Csv -Path $dataCSV | Select-Object -Last 1 | export-csv ./dataPredict.csv 
"Prediction Data"
Import-Csv -Path $dataCSV | Select-Object -Last 1

# Predict Value
$predictValues = 'Close'

$result = $null 
$dataPath = (Get-ChildItem ./dataPredict.csv).DirectoryName
$result = Get-H2OPrediction -url $url -dataset $dataCSV -predictData "$($dataPath)/dataPredict.csv" -modelAlgorithm $modelAlgorithm -modelSplit ".85,.15" -predictColumn $predictValues
"Confidence: $($result.modelConfidence)"
"Prediction: $($result.prediction.data)"

```
### Output 
```
Prediction Data

Open   : 1.46
High   : 1.47
Close  : 1.435
Low    : 1.435
Volume : 17366
Date   : 21-01-2020

Confidence: 0.000503095287004826
Prediction: 1.45785244828493
```

# Stop H2O AI
```
Stop-H2O
```

## Keep up to date
* [Visit my blog](http://darrenjrobinson.com/)
* ![](http://twitter.com/favicon.ico) [Follow on Twitter](https://twitter.com/darrenjrobinson)
