unit Main;

interface

uses
  { Winapi }
  Winapi.Windows, Winapi.Messages, Winapi.ShellApi,
  { System }
  System.SysUtils, System.Variants, System.Classes, System.DateUtils,
  { Vcl }
  Vcl.Graphics, Vcl.Controls, Vcl.Forms, Vcl.Dialogs, Vcl.StdCtrls,
  Vcl.WinXPanels, Vcl.ExtCtrls,
  { RESTRequest4D }
  RESTRequest4D,
  { UrlParser }
  UrlParser,
  { Horse }
  Horse,
  { JsonDataObjects }
  JsonDataObjects,
  { REST }
  REST.Types;

type
  TFMain = class(TForm)
    cpCards: TCardPanel;
    caIO: TCard;
    bvSeparator: TBevel;
    pncaIOBackground: TPanel;
    gbEnvio: TGroupBox;
    btSimpleUpload: TButton;
    pnBottom: TPanel;
    btOpenSettings: TButton;
    caOptions: TCard;
    bvBottomLine: TBevel;
    pncaOptionsBackground: TPanel;
    gbEndpoints: TGroupBox;
    lbAuthorizationEndpoint: TLabel;
    lbTokenEndpoint: TLabel;
    lbRedirectionEndpoint: TLabel;
    edAuthorizationEndpoint: TEdit;
    edTokenEndpoint: TEdit;
    edRedirectionEndpoint: TEdit;
    gbCodesTokens: TGroupBox;
    lbAuthenticationCode: TLabel;
    lbAccessToken: TLabel;
    lbRefreshToken: TLabel;
    edAuthenticationCode: TEdit;
    edAccessToken: TEdit;
    edRefreshToken: TEdit;
    gbClientSettings: TGroupBox;
    lbClientID: TLabel;
    lbClientSecret: TLabel;
    edClientID: TEdit;
    edClientSecret: TEdit;
    gbMiscSettings: TGroupBox;
    lbResponseType: TLabel;
    lbAccessScope: TLabel;
    edAccessScope: TEdit;
    cbResponseType: TComboBox;
    pnButtons: TPanel;
    btRunAuthentication: TButton;
    btAuthenticateRefreshToken: TButton;
    btGetAccessAndRefreshToken: TButton;
    pncaOptionsBottom: TPanel;
    btCancel: TButton;
    btApply: TButton;
    edTokenExpiryDate: TEdit;
    lbTokenExpiryDate: TLabel;
    btSessionUpload: TButton;
    mmOutput: TMemo;
    btApplyDefaults: TButton;
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
    procedure btSessionUploadClick(Sender: TObject);
    procedure btApplyDefaultsClick(Sender: TObject);
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

procedure TFMain.btApplyDefaultsClick(Sender: TObject);
begin
  edAuthorizationEndpoint.Text := 'https://www.dropbox.com/oauth2/authorize';
  edRedirectionEndpoint.Text := 'http://localhost:6569/auth';
  edTokenEndpoint.Text := 'https://api.dropboxapi.com/oauth2/token';
end;

procedure TFMain.btAuthenticateRefreshTokenClick(Sender: TObject);
var
  LResponse: IResponse;
  ResponseAsJson: TJDOJsonObject;
  LUrl: String;
begin
  LUrl := TUrlParser
            .New
            .BaseUrl(Trim(edTokenEndpoint.Text))
            .ToString;

  LResponse := TRequest
                .New
                .BaseURL(LUrl)
                .AddParam('grant_type', 'refresh_token')
                .AddParam('refresh_token', Trim(edRefreshToken.Text))
                .BasicAuthentication(Trim(edClientID.Text), Trim(edClientSecret.Text))
                .Post;

  if LResponse.StatusCode <> 200 then
  begin
    ShowMessage(LResponse.Content);
    Exit;
  end;

  ResponseAsJson := TJDOJsonObject.Parse(LResponse.Content) as TJDOJsonObject;

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
  ReloadDataFromJson;
  cpCards.ActiveCard := caIO;
end;

procedure TFMain.btGetAccessAndRefreshTokenClick(Sender: TObject);
var
  LResponseAsJson: TJDOJsonObject;
  LResponse: IResponse;
  LUrl: String;
begin
  LUrl := TUrlParser
            .New
            .BaseUrl(Trim(edTokenEndpoint.Text))
            .ToString;

  LResponse := TRequest
                .New
                .BaseURL(LUrl)
                .AddParam('code', Trim(edAuthenticationCode.Text))
                .AddParam('grant_type', 'authorization_code')
                .AddParam(redirect_uri_key, Trim(edRedirectionEndpoint.Text))
                .BasicAuthentication(edClientID.Text, edClientSecret.Text)
                .Post;

  if LResponse.StatusCode <> 200 then
  begin
    ShowMessage(LResponse.Content);
    Exit;
  end;

  LResponseAsJson := TJDOJsonObject.Parse(LResponse.Content) as TJDOJsonObject;

  try
    ShowMessage(LResponseAsJson.ToJSON);
    edAccessToken.Text := LResponseAsJson.S[access_token_key];
    edRefreshToken.Text := LResponseAsJson.S[refresh_token_key];
    edTokenExpiryDate.Text := DateTimeToStr(IncSecond(Now, LResponseAsJson.I[expires_in_key]));
  finally
    LResponseAsJson.Free;
  end;
end;

procedure TFMain.btOpenSettingsClick(Sender: TObject);
begin
  cpCards.ActiveCard := caOptions;
end;

procedure TFMain.btRunAuthenticationClick(Sender: TObject);
var
  LUrl: String;
begin
  LUrl := TUrlParser
            .New
            .BaseUrl(edAuthorizationEndpoint.Text)
            .AddParameter('response_type', cbResponseType.Text)
            .AddParameter('client_id', edClientID.Text)
            .AddParameter('redirect_uri', edRedirectionEndpoint.Text)
            .AddParameter('token_access_type', 'offline')
            .ToString;

  ShellExecute(0, 'open', PChar(LUrl), nil, nil, SW_SHOWNORMAL);

  THorse.Listen(6569);
end;

procedure TFMain.btSessionUploadClick(Sender: TObject);
var
  LUrl, LFile, LSessionID: String;
  LResponseAsJson, LDropboxApiArgs: TJDOJsonObject;
  LFileToUpload: TFileStream;
  LChunkOfFile: TMemoryStream;
  LResponse: IResponse;
  LDialog: TFileOpenDialog;
  LFileSize: Int64;

const
  LMaximumSize: Int64 = 157286400;

begin
  LUrl := TUrlParser
            .New
            .BaseUrl('https://content.dropboxapi.com/2/files/upload_session/start')
            .ToString;

  LDialog := TFileOpenDialog.Create(FMain);
  try
    if LDialog.Execute then
      LFile := LDialog.FileName;
  finally
    LDialog.Free;
  end;

  LFileToUpload := TFileStream.Create(LFile, fmOpenReadWrite);

  LDropboxApiArgs := TJDOJsonObject.Create;
  try
    LDropboxApiArgs.B['close'] := false;

    LFileSize := LFileToUpload.Size;

    LResponse := TRequest
                  .New
                  .BaseURL(LUrl)
                  .Token('Bearer '+Trim(edAccessToken.Text))
                  .AddHeader('Dropbox-API-Arg', LDropboxApiArgs.ToJSON, [poDoNotEncode])
                  .ContentType('application/octet-stream')
                  .Post;

    if LResponse.StatusCode <> 200 then
    begin
      mmOutput.Lines.Add('Session start response code: ' + IntToStr(LResponse.StatusCode));
      mmOutput.Lines.Add('Session response: ' + LResponse.Content);

      ShowMessage(LResponse.Content);
      Abort;
    end;

    mmOutput.Lines.Add('Session start response code: ' + IntToStr(LResponse.StatusCode));
    mmOutput.Lines.Add('Session response: ' + LResponse.Content);

    LResponseAsJson := TJDOJsonObject.Parse(LResponse.Content) as TJDOJsonObject;
    try
      LSessionID := LResponseAsJson.S['session_id'];
    finally;
      LResponseAsJson.Free;
    end;

    LDropboxApiArgs.Clear;

    LDropboxApiArgs.O['cursor'].S['session_id'] := LSessionID;
    LDropboxApiArgs.O['cursor'].I['offset'] := 0;
    LDropboxApiArgs.B['close'] := false;

    while LFileToUpload.Position < LFileSize do
    begin
      LChunkOfFile := TMemoryStream.Create;

      if ((LFileSize - LFileToUpload.Position) >= LMaximumSize) then
      begin
        LChunkOfFile.CopyFrom(LFileToUpload, LMaximumSize);

        LUrl := TUrlParser
          .New
          .BaseUrl('https://content.dropboxapi.com/2/files/upload_session/append_v2')
          .ToString;

        mmOutput.Lines.Add('Session append size: ' + IntToStr(LChunkOfFile.Size));
      end
      else
      begin
        LChunkOfFile.CopyFrom(LFileToUpload, (LFileSize - LFileToUpload.Position));

        LDropboxApiArgs.Remove('close');
        LDropboxApiArgs.O['commit'].S['path'] := '/'+ExtractFileName(LFile);
        LDropboxApiArgs.O['commit'].S['mode'] := 'add';
        LDropboxApiArgs.O['commit'].B['autorename'] := true;
        LDropboxApiArgs.O['commit'].B['mute'] := false;
        LDropboxApiArgs.O['commit'].B['strict_conflict'] := false;

        LUrl := TUrlParser
          .New
          .BaseUrl('https://content.dropboxapi.com/2/files/upload_session/finish')
          .ToString;

        mmOutput.Lines.Add('Session finish size: ' + IntToStr(LChunkOfFile.Size));
      end;

      mmOutput.Lines.Add('Session sending...');

      LResponse := TRequest
                    .New
                    .BaseURL(LUrl)
                    .Token('Bearer '+Trim(edAccessToken.Text))
                    .AddHeader('Dropbox-API-Arg', LDropboxApiArgs.ToJSON, [poDoNotEncode])
                    .ContentType('application/octet-stream')
                    .AddBody(LChunkOfFile)
                    .Post;

      if LResponse.StatusCode <> 200 then
      begin
        mmOutput.Lines.Add('upload response code: ' + IntToStr(LResponse.StatusCode));
        mmOutput.Lines.Add('upload response: ' + LResponse.Content);

        ShowMessage(LResponse.Content);
        Abort;
      end;

      mmOutput.Lines.Add('Session response code: ' + IntToStr(LResponse.StatusCode));
      mmOutput.Lines.Add('Session response: ' + LResponse.Content);

      LDropboxApiArgs.O['cursor'].I['offset'] := LFileToUpload.Position;
    end;

    LResponseAsJson := TJDOJsonObject.Parse(LResponse.Content) as TJDOJsonObject;

    try
      ShowMessage(LResponseAsJson.ToJSON(False));
    finally
      LResponseAsJson.Free;
    end;
  finally
    LDropboxApiArgs.Free;
    LFileToUpload.Free;
  end;
end;

procedure TFMain.btSimpleUploadClick(Sender: TObject);
var
  LUrl, LFile: String;
  LResponseAsJson, LDropboxApiArgs: TJDOJsonObject;
  LFileToUpload: TFileStream;
  LResponse: IResponse;
  LDialog: TFileOpenDialog;
begin
  LUrl := TUrlParser
            .New
            .BaseUrl('https://content.dropboxapi.com/2/files/upload')
            .ToString;

  LDialog := TFileOpenDialog.Create(FMain);
  try
    if LDialog.Execute then
      LFile := LDialog.FileName;
  finally
    LDialog.Free;
  end;

  LDropboxApiArgs := TJDOJsonObject.Create;
  try
    LDropboxApiArgs.S['path'] := '/'+ExtractFileName(LFile);

    LFileToUpload := TFileStream.Create(LFile, fmOpenReadWrite);

    LResponse := TRequest
                  .New
                  .BaseURL(LUrl)
                  .Token('Bearer '+Trim(edAccessToken.Text))
                  .AddHeader('Dropbox-API-Arg', LDropboxApiArgs.ToJSON, [poDoNotEncode])
                  .ContentType('application/octet-stream')
                  .AddBody(LFileToUpload)
                  .Post;
  finally
    LDropboxApiArgs.Free;
  end;

  if LResponse.StatusCode <> 200 then
  begin
    mmOutput.Lines.Add('upload response code: ' + IntToStr(LResponse.StatusCode));
    mmOutput.Lines.Add('upload response: ' + LResponse.Content);

    ShowMessage(LResponse.Content);
    Exit;
  end;

  mmOutput.Lines.Add('upload response code: ' + IntToStr(LResponse.StatusCode));
  mmOutput.Lines.Add('upload response: ' + LResponse.Content);

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

  cpCards.ActiveCard := caIO;
end;

end.
