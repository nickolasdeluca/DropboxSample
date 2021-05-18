unit Main;

interface

uses
  { Winapi }
  Winapi.Windows, Winapi.Messages, Winapi.ShellApi,
  { System }
  System.SysUtils, System.Variants, System.Classes, System.DateUtils,
  System.JSON,
  { Vcl }
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.WinXPanels, Vcl.ExtCtrls,
  { RESTRequest4D }
  RESTRequest4D,
  { UrlParser }
  UrlParser,
  { XComponents }
  XEdit, XGroupBox,
  { Horse }
  Horse,
  { JsonDataObjects }
  JsonDataObjects,

  REST.Types;

type
  TFMain = class(TForm)
    cpCards: TCardPanel;
    caIO: TCard;
    bvSeparator: TBevel;
    pncaIOBackground: TPanel;
    gbEnvio: TXGroupBox;
    btSimpleUpload: TButton;
    pnBottom: TPanel;
    btOpenSettings: TButton;
    caOptions: TCard;
    bvBottomLine: TBevel;
    pncaOptionsBackground: TPanel;
    gbEndpoints: TXGroupBox;
    lbAuthorizationEndpoint: TLabel;
    lbTokenEndpoint: TLabel;
    lbRedirectionEndpoint: TLabel;
    edAuthorizationEndpoint: TXEdit;
    edTokenEndpoint: TXEdit;
    edRedirectionEndpoint: TXEdit;
    gbCodesTokens: TXGroupBox;
    lbAuthenticationCode: TLabel;
    lbAccessToken: TLabel;
    lbRefreshToken: TLabel;
    edAuthenticationCode: TXEdit;
    edAccessToken: TXEdit;
    edRefreshToken: TXEdit;
    gbClientSettings: TXGroupBox;
    lbClientID: TLabel;
    lbClientSecret: TLabel;
    edClientID: TXEdit;
    edClientSecret: TXEdit;
    gbMiscSettings: TXGroupBox;
    lbResponseType: TLabel;
    lbAccessScope: TLabel;
    edAccessScope: TXEdit;
    cbResponseType: TComboBox;
    pnButtons: TPanel;
    btRunAuthentication: TButton;
    btAuthenticateRefreshToken: TButton;
    btGetAccessAndRefreshToken: TButton;
    pncaOptionsBottom: TPanel;
    btCancel: TButton;
    btApply: TButton;
    edTokenExpiryDate: TXEdit;
    lbTokenExpiryDate: TLabel;
    procedure btCancelClick(Sender: TObject);
    procedure btRunAuthenticationClick(Sender: TObject);
    procedure btGetAccessAndRefreshTokenClick(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure btApplyClick(Sender: TObject);
    procedure btOpenSettingsClick(Sender: TObject);
    procedure FormShow(Sender: TObject);
    procedure btAuthenticateRefreshTokenClick(Sender: TObject);
    procedure FormClose(Sender: TObject; var Action: TCloseAction);
    procedure btSimpleUploadClick(Sender: TObject);
  private
    procedure ReloadDataFromJson;
    { Private declarations }
  public
    { Public declarations }
  end;

var
  FMain: TFMain;
  Credentials: TJDOJsonObject;

implementation

{$R *.dfm}

uses Globals;

procedure TFMain.btApplyClick(Sender: TObject);
begin
  Credentials.S[auth_uri_key] := Trim(edAuthorizationEndpoint.Text);
  Credentials.S[client_id_key] := Trim(edClientID.Text);
  Credentials.S[client_secret_key] := Trim(edClientSecret.Text);
  Credentials.S[redirect_uri_key] := Trim(edRedirectionEndpoint.Text);
  Credentials.S[token_uri_key] := Trim(edTokenEndpoint.Text);

  Credentials.S[access_token_key] := Trim(edAccessToken.Text);
  Credentials.S[refresh_token_key] := Trim(edRefreshToken.Text);
  Credentials.D[expires_in_key] := StrToDateTime(edTokenExpiryDate.Text);

  Credentials.SaveToFile(credentials_file, False);

  cpCards.ActiveCard := caIO;
end;

procedure TFMain.btAuthenticateRefreshTokenClick(Sender: TObject);
var
  Response: String;
  ResponseAsJson: TJDOJsonObject;
begin
  Response := TRequest
                .New
                .BaseURL(
                  TUrlParser
                    .New
                    .BaseUrl(Trim(edTokenEndpoint.Text))
                    .ToString
                )
                .AddParam('grant_type', 'refresh_token')
                .AddParam('refresh_token', Trim(edRefreshToken.Text))
                .BasicAuthentication(Trim(edClientID.Text), Trim(edClientSecret.Text))
                .Post
                .Content;

  ResponseAsJson := TJDOJsonObject.Parse(Response) as TJDOJsonObject;

  try
    ShowMessage(ResponseAsJson.ToJSON(False));

    edAccessToken.Text := ResponseAsJson.S[access_token_key];
    edTokenExpiryDate.Text := DateTimeToStr(IncSecond(Now, ResponseAsJson.I[expires_in_key]));
  finally
    ResponseAsJson.Free;
  end;
end;

procedure TFMain.btCancelClick(Sender: TObject);
begin
  cpCards.ActiveCard := caIO;
end;

procedure TFMain.btGetAccessAndRefreshTokenClick(Sender: TObject);
var
  Response: String;
  ResponseAsJson: TJDOJsonObject;
begin
  Response := TRequest
                .New
                .BaseURL(
                  TUrlParser
                    .New
                    .BaseUrl(Trim(edTokenEndpoint.Text))
                    .ToString)
                .AddParam('code', Trim(edAuthenticationCode.Text))
                .AddParam('grant_type', 'authorization_code')
                .AddParam(redirect_uri_key, Trim(edRedirectionEndpoint.Text))
                .BasicAuthentication(edClientID.Text, edClientSecret.Text)
                .Post
                .Content;

  ResponseAsJson := TJDOJsonObject.Parse(Response) as TJDOJsonObject;

  try
    ShowMessage(ResponseAsJson.ToJSON);
    edAccessToken.Text := ResponseAsJson.S[access_token_key];
    edRefreshToken.Text := ResponseAsJson.S[refresh_token_key];
    edTokenExpiryDate.Text := DateTimeToStr(IncSecond(Now, ResponseAsJson.I[expires_in_key]));
  finally
    ResponseAsJson.Free;
  end;
end;

procedure TFMain.btOpenSettingsClick(Sender: TObject);
begin
  cpCards.ActiveCard := caOptions;
end;

procedure TFMain.btRunAuthenticationClick(Sender: TObject);
begin
  ShellExecute(0,
    'open',
    PChar(
      TUrlParser
        .New
        .BaseUrl(edAuthorizationEndpoint.Text)
        .AddParameter('response_type', cbResponseType.Text)
        .AddParameter('client_id', edClientID.Text)
        .AddParameter('redirect_uri', edRedirectionEndpoint.Text)
        .AddParameter('token_access_type', 'offline')
        .ToString
      ),
    nil,
    nil,
    SW_SHOWNORMAL
  );

  THorse.Listen(6569);
end;

procedure TFMain.btSimpleUploadClick(Sender: TObject);
var
  LUrl: String;
  LResponseAsJson: TJDOJsonObject;
  LFileToUpload: TFileStream;
  LResponse: IResponse;
begin
  LUrl := TUrlParser
            .New
            .BaseUrl('https://content.dropboxapi.com/2/files/upload')
            .ToString;

  LFileToUpload := TFileStream.Create('teste.txt', fmOpenReadWrite);

  LResponse := TRequest
                .New
                .BaseURL(LUrl)
                .Token('Bearer '+Trim(edAccessToken.Text))
                .AddHeader('Dropbox-API-Arg', '{"path": "/teste.txt"}', [poDoNotEncode])
                .ContentType('application/octet-stream')
                .AddBody(LFileToUpload)
                .Post;

  if LResponse.StatusCode <> 200 then
  begin
    ShowMessage(LResponse.Content);
    Exit;
  end;

  LResponseAsJson := TJDOJsonObject.Parse(LResponse.Content) as TJDOJsonObject;
  try
    ShowMessage(LResponseAsJson.ToJSON(False));
  finally
    LResponseAsJson.Free;
  end;
end;

procedure TFMain.FormClose(Sender: TObject; var Action: TCloseAction);
begin
  Credentials.Free;
end;

procedure TFMain.FormCreate(Sender: TObject);
begin
  if FileExists(credentials_file) then
    Credentials := TJDOJsonObject.ParseFromFile(credentials_file) as TJDOJsonObject
  else
    Credentials := TJDOJsonObject.Create;

  THorse.Get('/auth',
    procedure(Req: THorseRequest; Res: THorseResponse; Next: TProc)
    var
      code: String;
    begin
      Req.Query.TryGetValue('code', code);

      if not(code.IsEmpty) then
      begin
        FMain.edAuthenticationCode.Text := code;

        THorse.StopListen;

        Res.Send('OK!');
      end;
    end);
end;

procedure TFMain.FormShow(Sender: TObject);
begin
  ReloadDataFromJson;
end;

procedure TFMain.ReloadDataFromJson;
begin
  edAuthorizationEndpoint.Text := Credentials.S[auth_uri_key];
  edClientID.Text := Credentials.S[client_id_key];
  edClientSecret.Text := Credentials.S[client_secret_key];
  edRedirectionEndpoint.Text := Credentials.S[redirect_uri_key];
  edTokenEndpoint.Text := Credentials.S[token_uri_key];

  edAccessToken.Text := Credentials.S[access_token_key];
  edRefreshToken.Text := Credentials.S[refresh_token_key];
  edTokenExpiryDate.Text := DateTimeToStr(Credentials.D[expires_in_key]);
end;

end.
