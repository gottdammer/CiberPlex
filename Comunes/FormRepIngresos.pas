unit FormRepIngresos;
{$mode objfpc}{$H+}
interface
uses
  Classes, SysUtils, dateutils, FileUtil, Forms, Controls, Graphics, Dialogs,
  ExtCtrls, StdCtrls, EditBtn, Grids, Menus, ActnList, LCLProc, ComCtrls,
  Clipbrd, Globales, RegistrosVentas, FormAgrupVert,
  UtilsGrilla, MisUtils;
type

  { TfrmRepIngresos }
  TfrmRepIngresos = class(TForm)
  published
    acGenCopTod: TAction;
    ActionList1: TActionList;
    Button1: TButton;
    btnConfig: TButton;
    ComboBox1: TComboBox;
    GroupBox1: TGroupBox;
    Label4: TLabel;
    optDia: TRadioButton;
    optSem: TRadioButton;
    optMes: TRadioButton;
    optsDatos: TRadioGroup;
    StatusBar1: TStatusBar;
    TipoReg: TCheckGroup;
    dat1: TDateEdit;
    dat2: TDateEdit;
    grilla: TStringGrid;
    Label1: TLabel;
    Label2: TLabel;
    MenuItem1: TMenuItem;
    Panel1: TPanel;
    PopupMenu1: TPopupMenu;
    Splitter1: TSplitter;
    procedure acGenCopTodExecute(Sender: TObject);
    procedure btnConfigClick(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure ComboBox1Change(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure optDiaChange(Sender: TObject);
    procedure optMesChange(Sender: TObject);
    procedure optSemChange(Sender: TObject);
  private
    regs: regIng_list;
    agrVert: TAgrVer;  //agrupamiento vertical
    griRegistros : TUtilGrilla;
    griAgrupados : TUtilGrilla;
    catsHor: TStringList;   //valores de dispersión horizontal
    catsVer: TStringList;   //valores de dispersión vertical
    procedure CreaCategoriasHoriz(campo: integer);
    function DoReqCadMoneda(valor: double): string;
    function FilaComoTexto(f: integer): string;
    procedure LimpiarCategoriasVert;
    procedure LLenarGrilla;
    procedure LlenarRegistro(f: integer; reg: regIng);
    procedure ReporteAgrupado(agrupVert: TAgrVer);
    procedure ReporteRegistros;
  public
    local: string;
    OnReqCadMoneda: TevReqCadMoneda;
    procedure Exec(Alocal: string);
  end;

var
  frmRepIngresos: TfrmRepIngresos;

implementation
{$R *.lfm}
{ TfrmRepIngresos }
procedure TfrmRepIngresos.LlenarRegistro(f: integer; reg: regIng);
{Llena los datos de un registro en una fila de la grilla}
begin
  grilla.Cells[1, f] := reg.ident;
  grilla.Cells[2, f] := reg.serie;
  grilla.Cells[3, f] := reg.FECHA_LOG_str;
  //grilla.Cells[4, f] := reg.FECHA_LOG_str;
  grilla.Cells[5, f] := reg.USUARIO;
  grilla.Cells[6, f] := reg.vser;
  grilla.Cells[7, f] := reg.vfec_str;
  grilla.Cells[8, f] := reg.cat;
  grilla.Cells[9, f] := reg.subcat;
  grilla.Cells[10, f] := FloatToStr(reg.Cant);
  grilla.Cells[11, f] := reg.pUnit;
  grilla.Cells[12, f] := OnReqCadMoneda(reg.total);
  grilla.Cells[13, f] := reg.estado;
  grilla.Cells[14, f] := reg.descrip;
  grilla.Cells[15, f] := reg.coment;
  grilla.Cells[16, f] := reg.fragment;
  grilla.Cells[17, f] := reg.codPro;
  grilla.Cells[18, f] := reg.pVen;
end;
procedure TfrmRepIngresos.ReporteRegistros;
{Genera el reporte detallado, usando la lista de registros "regs".}
var
  f: Integer;
  reg: regIng;
  tot: Double;

begin
  //LLena grilla
  //DbgOut('Llenando grilla...');
  griRegistros.AsignarGrilla(grilla);
  grilla.BeginUpdate;
  grilla.RowCount:=1+regs.Count;  //hace espacio
  f := 1;
  tot := 0.0;
  for reg in regs do begin
    LlenarRegistro(f, reg);
    inc(f);
    tot := tot + reg.total;
  end;
  grilla.EndUpdate();
  //consoleTickCount('');
  StatusBar1.Panels[1].Text:='Num. Ventas = ' + IntToSTr(regs.Count) +
                             ', Total Ingresos = ' + OnReqCadMoneda(tot);
end;
procedure TfrmRepIngresos.CreaCategoriasHoriz(campo: integer);
  function CreaCategoriaHoriz(const categ: string): integer;
  {Busca un valor en catsHor. Si no existe, lo agrega. Devuelve el índice de su
  posición.
  Se usa esta rutina en lugar de Find(), porque se probó que es más rápida (al menos para
  pocos grupos) y a la vez facilita reusar el código. Sin embargo, a diferencia de Fins(),
  no se ordenan los encabezados.}
  var
    i: Integer;
  begin
    //Busca campo
    for i:=0 to catsHor.Count-1 do begin
      if catsHor[i] = categ then begin
        //Ya existe campo, solo devuelve el índice.
        exit(i);
      end;
    end;
    //No existe
    catsHor.Add(categ);
    Result := catsHor.Count-1;
  end;
var
  reg: regIng;
begin
  catsHor.Sorted := false;  //CreaCategoriaHoriz() trabaja así.
  catsHor.Clear;
  case campo of
  1: begin
       for reg in regs do begin
         reg.posHor := CreaCategoriaHoriz(reg.cat);
       end;
     end;
  2: begin
       for reg in regs do begin
         reg.posHor := CreaCategoriaHoriz(reg.subcat);
       end;
     end;
  3: begin
       for reg in regs do begin
         reg.posHor := CreaCategoriaHoriz(reg.USUARIO);
       end;
     end;
  end;
end;
function TfrmRepIngresos.DoReqCadMoneda(valor: double): string;
begin
  Result := FloatToStr(valor);
end;
procedure TfrmRepIngresos.ReporteAgrupado(agrupVert: TAgrVer);
{Genera el reporte argupado, usando la lista de archivos "regs".}
var
  i  : Integer;
  reg: regIng;
  tmp: String;
  valores: TCPCellValues;
  tot: Extended;
begin
  catsVer.Clear;
  //////// Crea dispersión vertical y acumula contador
  tot := 0.0;
  for reg in regs do begin
    tmp := FechaACad(reg.vfec, agrupVert, frmAgrupVert.ComboBox2.ItemIndex);
    if catsVer.Find(tmp, i) then begin
      //Ya existe en "i"
      valores := TCPCellValues(catsVer.Objects[i]);
    end else begin
      //Es nuevo, se debe crear
      catsVer.Add(tmp);
      valores := TCPCellValues.Create(catsHor.Count);  //crea objeto
      catsVer.Objects[catsVer.Count-1] := valores;  //guarda la referencia
    end;
    if optsDatos.ItemIndex = 0 then
      valores.items[reg.posHor] += reg.total  //acumula en la celda que corresponde
    else
      valores.items[reg.posHor] += reg.Cant; //acumula en la celda que corresponde
    tot := tot + reg.total;
  end;
  StatusBar1.Panels[1].Text:='Num. Ventas = ' + IntToSTr(regs.Count) +
                             ', Total Ingresos = ' + OnReqCadMoneda(tot);
end;
procedure TfrmRepIngresos.LLenarGrilla;
{Llena la grilla con datos de las listas catsHor y catsVer.}
var
  c, i, desplazCol: Integer;
  valores: TCPCellValues;
  tot : Double;
  fecStr: String;
begin
  //DbgOut('Llenando grilla...');
  grilla.BeginUpdate;
  //////// Crea las columnas
  griAgrupados.IniEncab;
  griAgrupados.AgrEncabNum('N°'       , 30);
  griAgrupados.AgrEncabTxt('FECHA'    , 70); //Campo Fecha
  if agrVert = tavDia then  //Campos adicionales de reporte por día
    desplazCol := frmAgrupVert.VerifCamposAdic_Dia(griAgrupados, 2);
  if agrVert = tavMes then  //Campos adicionales de reporte por día
    desplazCol := frmAgrupVert.VerifCamposAdic_Mes(griAgrupados, 2);
  for c:=0 to catsHor.Count-1 do begin
    griAgrupados.AgrEncabNum(catsHor[c], 55);
  end;
  griAgrupados.AgrEncabNum('TOTAL'    , 70); //campo final
  griAgrupados.FinEncab(false);  //sin actualizar aún
  griAgrupados.AsignarGrilla(grilla);  //actualiza
  /////// Llema las filas
  grilla.RowCount:=1+catsVer.Count;  //hace espacio
  for i:=0 to catsVer.Count-1 do begin
    //columna de categoría
    valores := TCPCellValues(catsVer.Objects[i]);
    tot := 0;  //para acumular
    // cáculo de campos agrupados /////////
    fecStr := catsVer[i];
    grilla.Cells[1, i+1] := fecStr;  //Campo Fecha
    if agrVert = tavDia then begin  //Campos adicionales de reporte por día
      frmAgrupVert.EscribirCamposAdic_Dia(fecStr, grilla, i+1);
    end else if agrVert = tavMes then begin
      frmAgrupVert.EscribirCamposAdic_Mes(fecStr, grilla, i+1);
    end;
    //campos de datos
    for c := 0 to catsHor.Count-1 do begin
      if optsDatos.ItemIndex = 0 then  //por Ingresos totales
        grilla.Cells[c+2+desplazCol, i+1] := OnReqCadMoneda(valores.items[c])
      else                             //por cantidad
        grilla.Cells[c+2+desplazCol, i+1] := FloatToStr(valores.items[c]);
      tot += valores.items[c];
    end;
    //llena columna total
    if optsDatos.ItemIndex = 0 then  //por Ingresos totales
      grilla.Cells[grilla.ColCount-1, i+1] := OnReqCadMoneda(tot)
    else
      grilla.Cells[grilla.ColCount-1, i+1] := FloatToStr(tot);
  end;
  grilla.EndUpdate();
  //consoleTickCount('');
end;
procedure TfrmRepIngresos.LimpiarCategoriasVert;
{Limpia la lista de categorías verticales}
var
  i: Integer;
begin
  //Libera objetos de celdas
  for i:=0 to catsVer.Count-1 do begin
    catsVer.Objects[i].Destroy;
  end;
  catsVer.Clear;
end;
procedure TfrmRepIngresos.Button1Click(Sender: TObject);
begin
  //Genera lista de archivos
  consoleTickStart;
  DbgOut('Llenando lista de registros...');
  LeerIngresos(regs, dat1.Date, dat2.Date, Local, TipoReg.Checked[0],  //llena "regs"
               TipoReg.Checked[1], TipoReg.Checked[2], rutApp + '\datos');
  consoleTickCount('');
  DbgOut('Creando reporte...');
  //Genera el rpeorte
  case ComboBox1.Text of
  'Registros': begin
      ReporteRegistros;
    end;
  'Por categoría': begin
      CreaCategoriasHoriz(1);
      ReporteAgrupado(agrVert);
      LLenarGrilla;   //Escribe datos en grilla
      LimpiarCategoriasVert;
    end;
  'Por Subcategoría': begin
      CreaCategoriasHoriz(2);
      ReporteAgrupado(agrVert);
      LLenarGrilla;   //Escribe datos en grilla
      LimpiarCategoriasVert;
    end;
  'Por Usuario': begin
      CreaCategoriasHoriz(3);
      ReporteAgrupado(agrVert);
      LLenarGrilla;  //Escribe datos en grilla
      LimpiarCategoriasVert;
    end;
  end;
  consoleTickCount('');
  debugln('');
end;
procedure TfrmRepIngresos.ComboBox1Change(Sender: TObject);
begin
  GroupBox1.Visible := ComboBox1.ItemIndex > 0;
  optsDatos.Visible := ComboBox1.ItemIndex > 0;
end;
procedure TfrmRepIngresos.FormCreate(Sender: TObject);
begin
  catsHor:= TStringList.Create;
  catsHor.Sorted:=true;
  catsVer:= TStringList.Create;
  catsVer.Sorted:=true;
  regs:= regIng_list.Create(true);
  //reportes:= TCenReporte_list.Create(true);
  dat1.Date:=now;
  dat2.Date:=now;
  //Configura grilla de reporte de registros
  griRegistros := TUtilGrilla.Create(nil);
  griRegistros.IniEncab;
  griRegistros.AgrEncabNum('N°'          , 35);
  griRegistros.AgrEncabTxt('_IDEN'       , 20);
  griRegistros.AgrEncabNum('SERIE'       , 30);
  griRegistros.AgrEncabTxt('COL_FECHA'   , 110);
  griRegistros.AgrEncabTxt('MES'         , 40);
  griRegistros.AgrEncabTxt('USUARIO'     , 50);
  griRegistros.AgrEncabNum('VSERIE'      , 30);
  griRegistros.AgrEncabTxt('VFECHA'      , 110);
  griRegistros.AgrEncabTxt('CATEGORÍA'   , 60);
  griRegistros.AgrEncabTxt('SUBCATEGORÍA', 70);
  griRegistros.AgrEncabNum('CANTIDAD'    , 30);
  griRegistros.AgrEncabNum('PRC.UNITARIO', 50);
  griRegistros.AgrEncabNum('TOTAL'       , 60);
  griRegistros.AgrEncabNum('ESTADO'      , 30);
  griRegistros.AgrEncabTxt('DESCRIPCIÓN' , 140);
  griRegistros.AgrEncabTxt('COMENTARIO'  , 80);
  griRegistros.AgrEncabNum('FRAGMENTO'   , 30);
  griRegistros.AgrEncabTxt('CODPRO'      , 80);
  griRegistros.AgrEncabTxt('PTO.VENTA'   , 70);
  griRegistros.FinEncab;
  griRegistros.OpAutoNumeracion:=true;
  griRegistros.OpDimensColumnas:=true;
  griRegistros.OpEncabezPulsable:=true;
  griRegistros.OpResaltarEncabez:=true;
  griRegistros.OpResaltFilaSelec:=true;
  griRegistros.MenuCampos:=true;
  //Configura grilla de reporte agrupado
  griAgrupados := TUtilGrilla.Create(nil);
  griAgrupados.IniEncab;
  griAgrupados.AgrEncabNum('N°'       , 35);
  griAgrupados.AgrEncabTxt('FECHA'     , 20);
  griAgrupados.FinEncab;
  griAgrupados.OpAutoNumeracion:=true;
  griAgrupados.OpDimensColumnas:=true;
  griAgrupados.OpEncabezPulsable:=true;
  griAgrupados.OpResaltarEncabez:=true;
  griAgrupados.OpResaltFilaSelec:=true;

  //Llena lista de reportes
  ComboBox1.Clear;
  ComboBox1.AddItem('Registros', nil);
  ComboBox1.AddItem('Por categoría', nil);
  ComboBox1.AddItem('Por Subcategoría', nil);
  ComboBox1.AddItem('Por Usuario', nil);
  ComboBox1.ItemIndex:=0;  //selecciona el primero

  //Actuliza interfaz
  ComboBox1Change(self);
  optDia.Checked:=true;  //inicializa opción
  optsDatos.ItemIndex:=0; //inicializa tipo de dato
  //Define un formato, por defecto, de moneda.
  OnReqCadMoneda:=@DoReqCadMoneda;
end;
procedure TfrmRepIngresos.FormDestroy(Sender: TObject);
begin
  griAgrupados.Destroy;
  griRegistros.Destroy;
  //reportes.Destroy;
  regs.Destroy;
  catsVer.Destroy;
  catsHor.Destroy;
end;
procedure TfrmRepIngresos.Exec(Alocal: string);
begin
  local := Alocal;
  frmAgrupVert.chkIncSemana.Checked := true;
  frmAgrupVert.chkIncMes.Checked := true;
  frmAgrupVert.chkIncDia.Checked := true;
  frmAgrupVert.chkMesIncMes.Checked := true;
  frmAgrupVert.chkMesIncAno.Checked := true;
  Show;
end;
procedure TfrmRepIngresos.optDiaChange(Sender: TObject);
begin
  agrVert := tavDia;
end;
procedure TfrmRepIngresos.optSemChange(Sender: TObject);
begin
  agrVert := tavSem;
end;
procedure TfrmRepIngresos.optMesChange(Sender: TObject);
begin
  agrVert := tavMes;
end;
function TfrmRepIngresos.FilaComoTexto(f: integer): string;
{Devuelve los campos de una fila como texto separado por tabulaciones}
const
  COL_INI = 1;
var
  c: Integer;
begin
  Result := '';
  for c:=COL_INI to grilla.ColCount-1 do begin
    if c=COL_INI then Result := grilla.Cells[c,f]
    else Result := Result + #9 + grilla.Cells[c,f];
  end;
end;
procedure TfrmRepIngresos.acGenCopTodExecute(Sender: TObject);  //Copia toda la grilla
var
  f: Integer;
  tmp: String;
begin
  tmp := '';
  for f:=0 to grilla.RowCount-1 do begin
    tmp := tmp + FilaComoTexto(f) + LineEnding;
  end;
  Clipboard.AsText:=tmp;
end;
procedure TfrmRepIngresos.btnConfigClick(Sender: TObject);
begin
  if optDia.Checked then frmAgrupVert.PageControl1.PageIndex:=0;
  if optSem.Checked then frmAgrupVert.PageControl1.PageIndex:=1;
  if optMes.Checked then frmAgrupVert.PageControl1.PageIndex:=2;
  frmAgrupVert.Show;
end;

end.
//485
