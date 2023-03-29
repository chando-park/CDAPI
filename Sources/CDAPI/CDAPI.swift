
import Alamofire
import RxSwift

public typealias Model_P = Decodable

 /** API INFO **/
 public protocol CDAPIInfo{
     associatedtype DataType: Model_P
     associatedtype ResponseType: Response_P
     
     var short: String {get}
     var method: HTTPMethod {get}
     var parameters: Parameters? {get}
     var config: CDAPIConfig? {get set}
 }

 public extension CDAPIInfo{
     var address: String{
         if method == .get {
             return (self.config?.baseURL ?? "") + self.short + (self.parameters?.query ?? "")
         }else{
             return (self.config?.baseURL ?? "") + self.short
         }
     }
 }

 /** API CONFIG **/
 public protocol CDAPIConfig{
     var headers: HTTPHeaders?{get}
     var baseURL: String{get}
 }

 /** Response **/
 public protocol Response_P: Model_P{
     associatedtype DataType: Model_P
     
     var responseType: ResponseType {get set}
     var data: DataType? {get set}
     
     init(responseType: ResponseType, data: DataType?)
 }

 public enum ResponseType{
     case ok(message: String?)
     case error(code: Int, message: String?)
     
     var message: String?{
         switch self {
         case .ok(let message):
             return message
         case .error(_, let message):
             return message
         }
     }
 }

 public protocol CDAPI: AnyObject{
     
     var session: SessionManager{get set}
     var trustManager: ServerTrustPolicyManager? {get set}
     var sessionConfig: URLSessionConfiguration?{get set}
 }

 public extension CDAPI{
     
     func call<T: CDAPIInfo>(api: T, completed: @escaping (T.ResponseType)->()){
         
         self.session.request(URL(string: api.address)!, method: api.method, parameters: api.parameters, headers: api.config?.headers).responseData { res in
             switch res.result{
             case .success(_):
                 if let data = res.value{
                     do{
                         let decodingData = try JSONDecoder().decode(T.ResponseType.self, from: data)
                         if let _ = decodingData.data{
                             completed(decodingData)
                         }else{
                             completed(T.ResponseType(responseType: .error(code: -1, message: "decoding error"), data: nil))
                         }
                     }catch(let e){
                         completed(T.ResponseType(responseType: .error(code: (e as? AFError)?.responseCode ?? -1, message: e.localizedDescription), data: nil))
                     }
                 }else{
                     completed(T.ResponseType(responseType: .error(code: (res.error as? AFError)?.responseCode ?? -1, message: res.error?.localizedDescription), data: nil))
                 }
                 break
             case .failure(_):
                 completed(T.ResponseType(responseType: .error(code: (res.error as? AFError)?.responseCode ?? -1, message: res.error?.localizedDescription), data: nil))
                 break
             }
         }
     }
     
     func callByRx<T: CDAPIInfo, R: Response_P>(_ api: T) -> Observable<R> where T.ResponseType == R {
         return Observable<R>.create { observer in
 #if DEBUG
             print("=======================")
             print("📲url: \(api.address)")
             print("📲parameters: \(String(describing: api.parameters))")
             print("📲method: \(api.method)")
             print("📲header: \(String(describing: api.config?.headers))")
 #endif
             
             let request = self.session.request(URL(string: api.address)!, method: api.method, parameters: api.parameters, headers: api.config?.headers).responseData { res in
                 switch res.result{
                 case .success(let value):
                     if let data = res.value{
                         do{
                             let decodingData = try JSONDecoder().decode(R.self, from: data)
                             observer.onNext(decodingData)
                         }
                         
                         
                         catch DecodingError.keyNotFound(let key, let context){
                             let errorMessgae = "could not find key \(key) in JSON: \(context.debugDescription)"
                             print(errorMessgae)
                             observer.onNext(R(responseType: ResponseType.error(code: 7771, message: errorMessgae), data: nil))
                         }
                         catch DecodingError.valueNotFound(let key, let context){
                             let errorMessgae = "could not find key \(key) in JSON: \(context.debugDescription)"
                             print(errorMessgae)
                             observer.onNext(R(responseType: ResponseType.error(code: 7772, message: errorMessgae), data: nil))
                         }
                         catch DecodingError.typeMismatch(let type, let context) {
                             let errorMessgae = "could not find key \(type) in JSON: \(context.debugDescription)"
                             print(errorMessgae)
                             observer.onNext(R(responseType: ResponseType.error(code: 7773, message: errorMessgae), data: nil))
                         } catch DecodingError.dataCorrupted(let context) {
                             let errorMessgae = "could not find key in JSON: \(context.debugDescription)"
                             print(errorMessgae)
                             observer.onNext(R(responseType: ResponseType.error(code: 7774, message: errorMessgae), data: nil))
                         }
                         catch var jsonError{
                             print("jsonError :\(jsonError)")
                             let errorMessgae = "\(jsonError.localizedDescription)"
                             observer.onNext(R(responseType: ResponseType.error(code: 7775, message: errorMessgae), data: nil))
                         }
                     }else{
                         observer.onNext(R(responseType: ResponseType.error(code: (res.error as? AFError)?.responseCode ?? -1, message: res.error?.localizedDescription), data: nil))
                     }
                     break
                 case .failure(_):
                     observer.onNext(R(responseType: ResponseType.error(code: (res.error as? AFError)?.responseCode ?? -1, message: res.error?.localizedDescription), data: nil))
                     break
                 }
                 observer.onCompleted()
             }.responseJSON { res in
 #if DEBUG
                 print("responseString \(String(describing: res.value))")
                 print("=======================")
 #endif
             }
             return Disposables.create {
                 request.cancel()
             }
         }
     }
 }


 extension Dictionary{
     var query: String{
         if(count == 0){
             return ""
         }
         let params = self
         let urlParams = params.compactMap({ (key, value) -> String in
                     "\(key)=\(value)"
         }).joined(separator: "&")
         var urlString = "?" + urlParams
         if let url = urlString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed){
             urlString = url
         }
         return urlString
     }
 }
