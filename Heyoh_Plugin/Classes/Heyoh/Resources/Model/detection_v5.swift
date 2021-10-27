//
// model.swift
//
// This file was automatically generated and should not be edited.
//

import CoreML


/// Model Prediction Input Type
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class modelInput : MLFeatureProvider {

    /// input as color (kCVPixelFormatType_32BGRA) image buffer, 256 pixels wide by 128 pixels high
    var input: CVPixelBuffer

    var featureNames: Set<String> {
        get {
            return ["input"]
        }
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        if (featureName == "input") {
            return MLFeatureValue(pixelBuffer: input)
        }
        return nil
    }
    
    init(input: CVPixelBuffer) {
        self.input = input
    }

    convenience init(inputWith input: CGImage) throws {
        let __input = try MLFeatureValue(cgImage: input, pixelsWide: 256, pixelsHigh: 128, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
        self.init(input: __input)
    }

    convenience init(inputAt input: URL) throws {
        let __input = try MLFeatureValue(imageAt: input, pixelsWide: 256, pixelsHigh: 128, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
        self.init(input: __input)
    }

    func setInput(with input: CGImage) throws  {
        self.input = try MLFeatureValue(cgImage: input, pixelsWide: 256, pixelsHigh: 128, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }

    func setInput(with input: URL) throws  {
        self.input = try MLFeatureValue(imageAt: input, pixelsWide: 256, pixelsHigh: 128, pixelFormatType: kCVPixelFormatType_32ARGB, options: nil).imageBufferValue!
    }
}


/// Model Prediction Output Type
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class modelOutput : MLFeatureProvider {

    /// Source provided by CoreML

    private let provider : MLFeatureProvider


    /// coords as multidimensional array of floats
    lazy var coords: MLMultiArray = {
        [unowned self] in return self.provider.featureValue(for: "coords")!.multiArrayValue
    }()!

    /// size_width as multidimensional array of floats
    lazy var size_width: MLMultiArray = {
        [unowned self] in return self.provider.featureValue(for: "size_width")!.multiArrayValue
    }()!

    /// size_height as multidimensional array of floats
    lazy var size_height: MLMultiArray = {
        [unowned self] in return self.provider.featureValue(for: "size_height")!.multiArrayValue
    }()!

    /// side_squeezed as multidimensional array of floats
    lazy var side_squeezed: MLMultiArray = {
        [unowned self] in return self.provider.featureValue(for: "side_squeezed")!.multiArrayValue
    }()!

    var featureNames: Set<String> {
        return self.provider.featureNames
    }
    
    func featureValue(for featureName: String) -> MLFeatureValue? {
        return self.provider.featureValue(for: featureName)
    }

    init(coords: MLMultiArray, size_width: MLMultiArray, size_height: MLMultiArray, side_squeezed: MLMultiArray) {
        self.provider = try! MLDictionaryFeatureProvider(dictionary: ["coords" : MLFeatureValue(multiArray: coords), "size_width" : MLFeatureValue(multiArray: size_width), "size_height" : MLFeatureValue(multiArray: size_height), "side_squeezed" : MLFeatureValue(multiArray: side_squeezed)])
    }

    init(features: MLFeatureProvider) {
        self.provider = features
    }
}


/// Class for model loading and prediction
@available(macOS 10.15, iOS 13.0, tvOS 13.0, watchOS 6.0, *)
class detection_v5 {
    let model: MLModel

    /// URL of model assuming it was installed in the same bundle as this class
    class var urlOfModelInThisBundle : URL {
        let bundle = Bundle(for: self)
        return bundle.url(forResource: "detection_v5", withExtension:"mlmodelc")!
    }

    /**
        Construct model instance with an existing MLModel object.

        Usually the application does not use this initializer unless it makes a subclass of model.
        Such application may want to use `MLModel(contentsOfURL:configuration:)` and `model.urlOfModelInThisBundle` to create a MLModel object to pass-in.

        - parameters:
          - model: MLModel object
    */
    init(model: MLModel) {
        self.model = model
    }

    /**
        Construct model instance by automatically loading the model from the app's bundle.
    */
    @available(*, deprecated, message: "Use init(configuration:) instead and handle errors appropriately.")
    convenience init() {
        try! self.init(contentsOf: type(of:self).urlOfModelInThisBundle)
    }

    /**
        Construct a model with configuration

        - parameters:
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(configuration: MLModelConfiguration) throws {
        try self.init(contentsOf: type(of:self).urlOfModelInThisBundle, configuration: configuration)
    }

    /**
        Construct model instance with explicit path to mlmodelc file
        - parameters:
           - modelURL: the file url of the model

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL) throws {
        try self.init(model: MLModel(contentsOf: modelURL))
    }

    /**
        Construct a model with URL of the .mlmodelc directory and configuration

        - parameters:
           - modelURL: the file url of the model
           - configuration: the desired model configuration

        - throws: an NSError object that describes the problem
    */
    convenience init(contentsOf modelURL: URL, configuration: MLModelConfiguration) throws {
        try self.init(model: MLModel(contentsOf: modelURL, configuration: configuration))
    }

    /**
        Construct model instance asynchronously with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
//    @available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
//    class func load(configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<model, Error>) -> Void) {
//        return self.load(contentsOf: self.urlOfModelInThisBundle, configuration: configuration, completionHandler: handler)
//    }

    /**
        Construct model instance asynchronously with URL of the .mlmodelc directory with optional configuration.

        Model loading may take time when the model content is not immediately available (e.g. encrypted model). Use this factory method especially when the caller is on the main thread.

        - parameters:
          - modelURL: the URL to the model
          - configuration: the desired model configuration
          - handler: the completion handler to be called when the model loading completes successfully or unsuccessfully
    */
//    @available(macOS 11.0, iOS 14.0, tvOS 14.0, watchOS 7.0, *)
//    class func load(contentsOf modelURL: URL, configuration: MLModelConfiguration = MLModelConfiguration(), completionHandler handler: @escaping (Swift.Result<model, Error>) -> Void) {
//        MLModel.__loadContents(of: modelURL, configuration: configuration) { (model, error) in
//            if let error = error {
//                handler(.failure(error))
//            } else if let model = model {
//                handler(.success(model(model: model)))
//            } else {
//                fatalError("SPI failure: -[MLModel loadContentsOfURL:configuration::completionHandler:] vends nil for both model and error.")
//            }
//        }
//    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as modelInput

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as modelOutput
    */
    func prediction(input: modelInput) throws -> modelOutput {
        return try self.prediction(input: input, options: MLPredictionOptions())
    }

    /**
        Make a prediction using the structured interface

        - parameters:
           - input: the input to the prediction as modelInput
           - options: prediction options 

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as modelOutput
    */
    func prediction(input: modelInput, options: MLPredictionOptions) throws -> modelOutput {
        let outFeatures = try model.prediction(from: input, options:options)
        return modelOutput(features: outFeatures)
    }

    /**
        Make a prediction using the convenience interface

        - parameters:
            - input as color (kCVPixelFormatType_32BGRA) image buffer, 256 pixels wide by 128 pixels high

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as modelOutput
    */
    func prediction(input: CVPixelBuffer) throws -> modelOutput {
        let input_ = modelInput(input: input)
        return try self.prediction(input: input_)
    }

    /**
        Make a batch prediction using the structured interface

        - parameters:
           - inputs: the inputs to the prediction as [modelInput]
           - options: prediction options 

        - throws: an NSError object that describes the problem

        - returns: the result of the prediction as [modelOutput]
    */
    func predictions(inputs: [modelInput], options: MLPredictionOptions = MLPredictionOptions()) throws -> [modelOutput] {
        let batchIn = MLArrayBatchProvider(array: inputs)
        let batchOut = try model.predictions(from: batchIn, options: options)
        var results : [modelOutput] = []
        results.reserveCapacity(inputs.count)
        for i in 0..<batchOut.count {
            let outProvider = batchOut.features(at: i)
            let result =  modelOutput(features: outProvider)
            results.append(result)
        }
        return results
    }
}
