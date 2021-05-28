using Newtonsoft.Json;
using System;
using System.Collections.Generic;
using System.Configuration;
using System.Data;
using System.Data.SqlClient;
using System.IO;
using System.Linq;
using System.Net;
using System.Net.Mail;
using System.Security.Cryptography;
using System.Text;
using System.Web;
using System.Web.Script.Serialization;
using System.Web.Script.Services;
using System.Web.Services;
using System.Xml;
using System.Xml.Serialization;

/// <summary>
/// 
///		Author:			Mike Stahr
///		Created:		9-20-2017
///		Lastest Update:	10/14/2019

/// </summary>
/// 

[System.Web.Script.Services.ScriptService]  // To allow this Web Service to be called from script, uncomment this line. 
[WebService(Namespace = "http://tempuri.org/")]
[WebServiceBinding(ConformsTo = WsiProfiles.None)]
public class api : WebService
{
    private int timeout = 30;

    private static int EncryptionPadding = 2048;    // Note: Small=1024, Big=2048
    private string encryptionKey = ConfigurationManager.AppSettings["encryptionKeys" + EncryptionPadding];

    private const string emailPasscode = "F1634F14FB7C3F5B364A01387457E37CE496E3B9B4D4554F67CEBA2199EA017247246749788BA2020642221F39C9576585BB124DF0ABF1CF71BC7A9348833BD4";

    #region ######################################################################################################################################################## NOTES about API

    /*	Dynamic object...
			List<Dictionary<string, object>> rows = new List<Dictionary<string, object>>();
			Dictionary<string, object> row = new Dictionary<string, object>();
			row.Add("Make", "G35");
			row.Add("Model", "25 -18 Turbo");
			row.Add("Year", 2014);
			rows.Add(car);

			row = new Dictionary<string, object>();
			row.Add("Make", "Honda");
			row.Add("Model", "Accord");
			row.Add("Year", 2015);
			rows.Add(car);

			serialize(rows);
	*/

    /* TEST STUFF
		public void _TEST() {
			Dictionary<string, Dictionary<string, object>> ret = new Dictionary<string, Dictionary<string, object>>();
			Dictionary<string, object> grades;
			Dictionary<string, object> student;

			// Student 1
			student = new Dictionary<string, object>();
			student.Add("firstName", "Tom");
			student.Add("lastName", "Ryan");
			student.Add("age", 24);
			student.Add("field1", "la'pinta");
			student.Add("field2", "la\"pinta");
			grades = new Dictionary<string, object>();
			grades.Add("t1", 66);
			grades.Add("t2", 57);
			grades.Add("t3", 99);
			grades.Add("t4", 99);
			student.Add("grades", grades);
			ret.Add("sid-1", student);


			// Student 2
			student = new Dictionary<string, object>();
			student.Add("firstName", "Tom");
			student.Add("lastName", "Ryan");
			student.Add("age", 24);
			student.Add("field1", "la'pinta");
			student.Add("field2", "la\"pinta");
			grades = new Dictionary<string, object>();
			grades.Add("t1", 66);
			grades.Add("t2", 57);
			grades.Add("t3", 99);
			grades.Add("t4", 99);
			student.Add("grades", grades);
			ret.Add("sid-2", student);

			serialize(ret);
		}
	*/


    #endregion

    #region ######################################################################################################################################################## Database Stuff

    private string conn = System.Configuration.ConfigurationManager.ConnectionStrings["DefaultConnection"].ConnectionString;
    private List<SqlParameter> parameters = new List<SqlParameter>();

    // This method is used in conjunction with a "user defined table" in the database
    public DataTable sqlExec(string sql, DataTable dt, string udtblParam)
    {
        DataTable ret = new DataTable();

        try
        {
            using (SqlConnection objConn = new SqlConnection(conn))
            {
                SqlCommand cmd = new SqlCommand(sql, objConn);
                cmd.CommandType = CommandType.StoredProcedure;
                SqlParameter tvparam = cmd.Parameters.AddWithValue(udtblParam, dt);
                tvparam.SqlDbType = SqlDbType.Structured;
                objConn.Open();
                ret.Load(cmd.ExecuteReader(CommandBehavior.CloseConnection));
            }
        }
        catch (Exception e)
        {
            setDataTableToError(ret, e);
        }
        parameters.Clear();
        return ret;
    }

    public DataTable sqlExec(string sql)
    {
        return sqlExecDataTable(sql);
    }

    public Object sqlExecFunction(string fn)
    {
        DataSet userDataset = new DataSet();
        Object ret = null;
        try
        {
            using (SqlConnection objConn = new SqlConnection(conn))
            {
                objConn.Open();
                SqlCommand command = new SqlCommand(fn, objConn);
                command.CommandType = CommandType.Text;
                command.Parameters.AddRange(parameters.ToArray());
                ret = command.ExecuteScalar();
                objConn.Close();
            }
        }
        catch (Exception e)
        {
            throw e;
        }

        parameters.Clear();
        return ret;
    }

    public DataTable sqlExecDataTable(string sql)
    {
        DataSet userDataset = new DataSet();
        try
        {
            using (SqlConnection objConn = new SqlConnection(conn))
            {
                SqlDataAdapter myCommand = new SqlDataAdapter(sql, objConn);
                myCommand.SelectCommand.CommandType = CommandType.StoredProcedure;
                myCommand.SelectCommand.Parameters.AddRange(parameters.ToArray());
                myCommand.Fill(userDataset);
            }
        }
        catch (Exception e)
        {
            //userDataset.Tables.Add();
            //setDataTableToError(userDataset.Tables[0], e);
            throw e;
        }

        parameters.Clear();
        if (userDataset.Tables.Count == 0) userDataset.Tables.Add();
        return userDataset.Tables[0];
    }

    public DataSet sqlExecDataSet(string sql)
    {

        DataSet userDataset = new DataSet();
        try
        {
            using (SqlConnection objConn = new SqlConnection(conn))
            {

                SqlDataAdapter myCommand = new SqlDataAdapter(sql, objConn);
                myCommand.SelectCommand.CommandTimeout = timeout;
                myCommand.SelectCommand.CommandType = CommandType.StoredProcedure;
                myCommand.SelectCommand.Parameters.AddRange(parameters.ToArray());
                myCommand.Fill(userDataset);
            }
        }
        catch (Exception e)
        {
            userDataset.Tables.Add();
            setDataTableToError(userDataset.Tables[0], e);
        }

        parameters.Clear();
        return userDataset;
    }

    private void setDataTableToError(DataTable tbl, Exception e)
    {

        tbl.Columns.Add(new DataColumn("Error", typeof(Exception)));

        DataRow row = tbl.NewRow();
        row["Error"] = e;
        try
        {
            tbl.Rows.Add(row);
        }
        catch (Exception) { }
    }

    public void addParam(string name, object value)
    {
        parameters.Add(new SqlParameter(name, value));
    }

    #endregion

    #region ######################################################################################################################################################## Serializer
    private enum serializeStyle
    {
        GENERAL,
        DATA_SET,
        DATA_TABLE,
        DICTIONARY,
        STREAM_JSON,
        OBJECT,
        SINGLE_TABLE_ROW,
        JSON_RETURN
    }

    private void send(object obj, serializeStyle style)
    {
        try
        {
            switch (style)
            {
                case serializeStyle.DATA_SET: serializeDataSet(sqlExecDataSet((string)obj)); break;
                case serializeStyle.DATA_TABLE: serializeDataTable(sqlExecDataTable((string)obj)); break;
                case serializeStyle.OBJECT: serializeObject(obj); break;
                case serializeStyle.SINGLE_TABLE_ROW: serializeSingleDataTableRow(sqlExecDataTable((string)obj)); break;
                case serializeStyle.DICTIONARY: serializeDictionary((Dictionary<object, object>)obj); break;
                case serializeStyle.STREAM_JSON: streamJson((string)obj); break;
                case serializeStyle.GENERAL: serialize(obj); break;
                case serializeStyle.JSON_RETURN: streamJson(sqlExecDataSet((string)obj)); break;
                default: serialize("Invalid serialization"); break;
            }
        }
        catch (Exception e)
        {
            serialize("Error during send(): " + e.Message);
        }
    }

    private List<Dictionary<string, object>> getTableRows(DataTable dt)
    {
        List<Dictionary<string, object>> rows = new List<Dictionary<string, object>>();
        Dictionary<string, object> row;
        row = new Dictionary<string, object>();
        foreach (DataRow dr in dt.Rows)
        {
            row = new Dictionary<string, object>();
            foreach (DataColumn col in dt.Columns)
                row.Add(col.ColumnName, dr[col]);
            rows.Add(row);
        }
        return rows;
    }

    // Streams out a JSON string
    public void streamJson(string jsonString)
    {
        try
        {
            HttpContext.Current.Response.Clear();
            HttpContext.Current.Response.ContentType = "application/json";
            HttpContext.Current.Response.StatusCode = 200;
            HttpContext.Current.Response.StatusDescription = "";
            HttpContext.Current.Response.AddHeader("content-length", Encoding.UTF8.GetBytes(jsonString).Length.ToString());
            // or...
            //HttpContext.Current.Response.AddHeader("content-length", "" + Buffer.ByteLength(Encoding.UTF8.GetBytes(jsonString)));
            HttpContext.Current.Response.Write(jsonString);
            HttpContext.Current.Response.Flush();
            HttpContext.Current.ApplicationInstance.CompleteRequest();
        }
        catch { }
    }

    // NEW - Converts a returned JSON dataset to a json object
    public void streamJson(DataSet ds)
    {
        string ret = "";
        try
        {
            foreach (DataTable dt in ds.Tables)
                foreach (DataRow dr in dt.Rows)
                    ret += dr.ItemArray[0];
        }
        catch (Exception e)
        {
            ret = "";
        }
        streamJson(ret);
    }

    // Simple method to serialize an object into a JSON string and write it to the Response Stream
    public void serialize(Object obj)
    {
        try
        {
            streamJson(new JavaScriptSerializer().Serialize(obj));
        }
        catch (Exception e)
        {
            streamJson(new JavaScriptSerializer().Serialize("Invalid serializable object. r2w Error 2212: " + e.Source));
        }
    }

    // Generate and serialize a single row from a returned data table. Method will only return the first row - even if there are more.
    public void serializeSingleDataTableRow(DataTable dt)
    {
        serializeSingleDataTableRow(dt, "");
    }

    public void serializeSingleDataTableRow(DataTable dt, params string[] excludeColumns)
    {
        Dictionary<string, object> row = new Dictionary<string, object>();

        if (dt.Rows.Count > 0)
            foreach (DataColumn col in dt.Columns)
                if (!excludeColumns.Contains(col.ColumnName))
                    row.Add(col.ColumnName, dt.Rows[0][col]);
        serialize(row);
    }

    // Serialize an entire table retreived from a data call
    public void serializeDataTable(DataTable dt)
    {
        serialize(getTableRows(dt));
    }


    // Serialize an multiple tables retreived from a data call
    public void serializeDataSet(DataSet ds)
    {
        List<object> ret = new List<object>();

        foreach (DataTable dt in ds.Tables)
            ret.Add(getTableRows(dt));
        serialize(ret);
    }

    // Just a test to see if we can take an object to XML status
    public void serializeXML<T>(T value)
    {
        string ret = "";

        if (value != null)
        {
            try
            {
                HttpContext.Current.Response.Clear();
                HttpContext.Current.Response.ContentType = "text/xml";

                var xmlserializer = new XmlSerializer(typeof(T));
                var stringWriter = new StringWriter();

                using (var writer = XmlWriter.Create(stringWriter))
                {
                    xmlserializer.Serialize(writer, value);
                    ret = stringWriter.ToString();
                }
            }
            catch (Exception) { }
            HttpContext.Current.Response.Write(ret);
            HttpContext.Current.Response.Flush();
            HttpContext.Current.ApplicationInstance.CompleteRequest();
        }
    }

    // Serialize a dictionary object to avoid having to create more classes
    public void serializeDictionary(Dictionary<object, object> dic)
    {
        serialize(dic.ToDictionary(item => item.Key.ToString(), item => item.Value.ToString()));
    }

    // Using generics this method will serialize a JSON package into a class structure or return a new instance of the class on error
    public T _download_serialized_json_data<T>(string url) where T : new()
    {
        using (var w = new WebClient())
        {
            try { return JsonConvert.DeserializeObject<T>(w.DownloadString(url)); } catch (Exception) { return new T(); }
        }
    }

    public T deserialize<T>(string obj) where T : new()
    {
        //======================================================================= Example
        //		See below for example
        //=======================================================================
        try { return JsonConvert.DeserializeObject<T>(obj); } catch (Exception) { return new T(); }
    }

    // Probably don't need this as one can just type "serialize(object to serialize);" but if every we do we have it.   
    // Not sure it will work for objects that have arrays of other objects though...
    public void serializeObject(Object obj)
    {
        Dictionary<string, object> row = new Dictionary<string, object>();
        row = new Dictionary<string, object>();
        var prop = obj.GetType().GetProperties();

        foreach (var props in prop)
            row.Add(props.Name, props.GetGetMethod().Invoke(obj, null));
        serialize(row);
    }

    public string convertObjToJSON(object o)
    {
        JavaScriptSerializer js = new JavaScriptSerializer();
        return js.Serialize(o);
    }

    //======================================================================================= EXAMPLE
    //[WebMethod]
    //public void sampleLogin() {
    //	CurrentUser u = new CurrentUser() { accountGUID = "C82C926F-E984-4710-B142-D2AAFB8FF9A3", startOfWeek = 1, units = 1, userName = "Hoya" };
    //	writeCookie("_r", convertObjToJSON(u), 8760); // 8760 = hours in a year
    //}
    //
    //[WebMethod]
    //public void sampleGetUser() {
    //	CurrentUser cu = deserialize<CurrentUser>(readCookie("_r"));
    //	serialize(deserialize<CurrentUser>(readCookie("_r")));
    //}

    //private class CurrentUser {
    //	public string accountGUID { get; set; }
    //	public string userName { get; set; }
    //	public int startOfWeek { get; set; } // 0 = sunday, 1 = monday
    //	public int units { get; set; } // 1 = Miles, 2 = Meters, 3 = Kilometers, 9 = Yards, 10 = Meter (hurdles), 12 = Minutes, 13 = Seconds
    //}

    #endregion

    #region ######################################################################################################################################################## Internal Methods


    // Uncomment the following line and run API 
    //[WebMethod]
    public void generateNewEncryptionKey(bool sm1024)
    {
        int EncryptionPadding = (sm1024 ? 1024 : 2048);
        var csp = new RSACryptoServiceProvider(EncryptionPadding);
        var key = csp.ExportParameters(true);
        string KeyString;
        {
            var sw = new System.IO.StringWriter();
            var xs = new System.Xml.Serialization.XmlSerializer(typeof(RSAParameters));
            xs.Serialize(sw, key);
            KeyString = sw.ToString();
        }
        streamJson(string.Format("&lt;RSAKeyValue&gt;&lt;Exponent&gt;{0}&lt;/Exponent&gt;&lt;Modulus&gt;{1}&lt;/Modulus&gt;&lt;P&gt;{2}&lt;/P&gt;&lt;Q&gt;{3}&lt;/Q&gt;&lt;DP&gt;{4}&lt;/DP&gt;&lt;DQ&gt;{5}&lt;/DQ&gt;&lt;InverseQ&gt;{6}&lt;/InverseQ&gt;&lt;D&gt;{7}&lt;/D&gt;&lt;/RSAKeyValue&gt;",
                                    Convert.ToBase64String(key.Exponent),
                                    Convert.ToBase64String(key.Modulus),
                                    Convert.ToBase64String(key.P),
                                    Convert.ToBase64String(key.Q),
                                    Convert.ToBase64String(key.DP),
                                    Convert.ToBase64String(key.DQ),
                                    Convert.ToBase64String(key.InverseQ),
                                    Convert.ToBase64String(key.D)
                                )
                  );
    }

    private string encrypt(string data)
    {
        using (var rsa = new RSACryptoServiceProvider(EncryptionPadding))
        {
            try
            {
                rsa.FromXmlString(encryptionKey);
                var encryptedData = rsa.Encrypt(Encoding.UTF8.GetBytes(data), true);
                var base64Encrypted = Convert.ToBase64String(encryptedData);
                return base64Encrypted;
            }
            finally
            {
                rsa.PersistKeyInCsp = false;
            }
        }
    }

    private string dencrypt(string data)
    {
        using (var rsa = new RSACryptoServiceProvider(EncryptionPadding))
        {
            try
            {
                var base64Encrypted = data;
                rsa.FromXmlString(encryptionKey);
                var resultBytes = Convert.FromBase64String(base64Encrypted);
                var decryptedBytes = rsa.Decrypt(resultBytes, true);
                var decryptedData = Encoding.UTF8.GetString(decryptedBytes);
                return decryptedData.ToString();
            }
            finally
            {
                rsa.PersistKeyInCsp = false;
            }
        }
    }

    private void writeCookie(string name, string value, double expiresHours)
    {
        HttpCookie cookie = new HttpCookie(name);
        cookie.Value = encrypt(value);
        cookie.Expires = DateTime.Now.AddHours(expiresHours);
        HttpContext.Current.Response.Cookies.Add(cookie);
    }

    private string readCookie(string name)
    {
        HttpRequest Request = System.Web.HttpContext.Current.Request;
        if (Request.Cookies[name] != null) return dencrypt(Request.Cookies[name].Value);
        return "";
    }

    private void sendEmail(string from, string to, string cc, string bcc, string subject, string message)
    {
        SmtpClient mailClient = null;
        try
        {
            string pw = ConfigurationManager.AppSettings["emailPW"];
            string fromAddress = ConfigurationManager.AppSettings["emailFrom"];
            mailClient = new SmtpClient("smtp.gmail.com", 587);  //'465
            NetworkCredential cred = new NetworkCredential(fromAddress, pw);
            MailMessage msg = new MailMessage();
            msg.IsBodyHtml = true;
            msg.From = new MailAddress(from);
            msg.To.Add(to);
            msg.Subject = subject;
            msg.Body = "<!DOCTYPE html><html><head><title>Email</title></head><body>" + HttpUtility.HtmlDecode(message) + "</body></html>";
            msg.ReplyToList.Add(from);
            if (cc.Trim().Length > 0) msg.CC.Add(cc);
            if (bcc.Trim().Length > 0) msg.Bcc.Add(bcc);
            mailClient.EnableSsl = true;
            mailClient.Credentials = cred;
            mailClient.Send(msg);
        }
        catch (Exception e) { streamJson(e.Message); }
        finally
        {
            try { mailClient.Dispose(); mailClient = null; } catch { }
        }
    }

    #endregion

    #region ######################################################################################################################################################## Internal Classes

    public class PermissionError
    {

        public int errorCode;
        public string message;

        public PermissionError() : this("You do not have permission to use this service", 0) { }

        public PermissionError(string message, int errorCode)
        {
            this.message = message;
            this.errorCode = errorCode;
        }

        public PermissionError(string message) : this(message, 0) { }

        public PermissionError(int errorCode) : this("You do not have permission to use this service", errorCode) { }

    }

    #endregion

    // Methods
    #region ######################################################################################################################################################## Email

    [WebMethod(Description = "Admin utility ONLY - gives ability to send email. Initial setup was for sending email when r-mail is sent to user")]
    public void email(string passcode, string from, string to, string cc, string bcc, string subject, string message)
    {
        if (!passcode.Equals(emailPasscode)) streamJson("-");
        sendEmail(from, to, cc, bcc, subject, message);
        streamJson("ok");
    }

    #endregion


    #region ######################################################################################################################################################## Begin Coding
    //=============================================================================================================================== 
    [WebMethod]
    public void getUserPosts(string userName)
    {
        addParam("@userName", userName);
        send("spGetUserPosts", serializeStyle.DATA_TABLE);
    }

    [WebMethod]
    public void createPost(string userName, string movieName, float score, string review)
    {
        addParam("@userName", userName);
        addParam("@movieName", movieName);
        addParam("@score", score);
        addParam("@review", review);
        send("spCreatePost", serializeStyle.DATA_TABLE);
    }

    [WebMethod]
    public void createUser(string userName, int age, Boolean isCritic, string firstName, string lastName, string email, string password)
    {
        addParam("@userName", userName);
        addParam("@age", age);
        addParam("@isCritic", isCritic);
        addParam("@firstName", firstName);
        addParam("@lastName", lastName);
        addParam("@email", email);
        addParam("@password", password);
        send("spCreateUser", serializeStyle.DATA_TABLE);
    }


    [WebMethod(Description = "SQL Server can return pure JSON - this is an example of how you can stream it directly to the user")]
    public void getVendorAndInvoiceData(int vendorID)
    {
        addParam("@VendorID", vendorID);
        streamJson(sqlExecDataSet("spGetVendorAndInvoiceData_JSON"));
    }

    [WebMethod]
    public void getVendorsByState(string state) {
        addParam("@state", state);
        send("spGetVendorsByState", serializeStyle.DATA_TABLE);
    }

    [WebMethod]
    public void getVendorsByStateByPage(string VendorState, int page, int count) {
        addParam("@VendorState", VendorState);
        addParam("@page", page);
        addParam("@count", count);
        send("spGetVendorsByStateByPage", serializeStyle.DATA_TABLE);
    }

    #endregion

}
