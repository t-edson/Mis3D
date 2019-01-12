{Define los objetos gráficos con los que trabajará nuestra aplicación.
 Todos ellos deben descender de TObjGraf, para que puedadn ser tratados por el motor
 de edición "ogMotEdicion".}

unit ObjGraficos;
{$mode objfpc}{$H+}
interface
uses
  Classes, Graphics, LCLProc, fgl,
  MotGraf3d, DefObjGraf;

type
//Tipo de entidad gráfica
TDXFentType = (
   etyLine      //línea
  ,etyCircle    //círculo
  ,etyPolyline  //polilínea
  ,etyInsert    //bloque
);

TObjGrafDXF = class;
TObjGrafDXF_list = specialize TFPGObjectList<TObjGrafDXF>;
{ TMiObjeto }
TMiObjeto = class(TObjGraf)  //objeto gráfico que dibujaremos
  procedure Dibujar; override;  //Dibuja el objeto gráfico
  constructor Create(mGraf: TMotGraf); override;
private
  procedure ReubicElemen; override;
end;

{ TObjGrafDXF }
{Se define al objeto para que sea compatible con archivos DXF.}
TObjGrafDXF = class(TObjGraf)  //objeto gráfico DXF
private
  pc0, pc1, pcM: TPtoCtrl;
  procedure PtoCtrl0_Move(xvTar, yvTar, dx, dy: Single);
  procedure PtoCtrl1_Move(xvTar, yvTar, dx, dy: Single);
  procedure PtoCtrlM_Move(xvTar, yvTar, dxv, dyv: Single);
public  //Campos equivalentes a los de una entidad DXF
  etype: TDXFentType;   //tipo de entidad
  idDxf: string;        //identificador de la entidad
  layer: string;
  color: string;
  style: string;
  isComplex: boolean;
  polyFlag: integer; {Bandera para polilíneas. Mapa de bits, cero por defecto:
    1 = This is a closed polyline (or a polygon mesh closed in the M direction).
    2 = Curve-fit vertices have been added.
    4 = Spline-fit vertices have been added.
    8 = This is a 3D polyline.
    16 = This is a 3D polygon mesh.
    32 = The polygon mesh is closed in the N direction.
    64 = The polyline is a polyface mesh.
    128 = The linetype pattern is generated continuously around the vertices of this polyline.}
    //propiedades gráficas
  P0: TMotPoint;
  P1: TMotPoint;
  radius: double;
  vertexs: TObjGrafDXF_list;   {Lista de Vertex. Solo se instancia para objetos
                               complejos. OJO!!! Es muy pesado guardar una lista de
                               TObjGrafDXF. Debería optimizarse}
  blkName: string;    //usado cuando es de tipo etyInsert.
public
  procedure SetP0(const xv,yv,zv: Single);
  procedure SetP1(const xv,yv,zv: Single);
  procedure ReubicElemen; override;
public
  procedure Dibujar; override;  //Dibuja el objeto gráfico
  function LoSelecciona(xp, yp:integer): Boolean; override;
  constructor Create(mGraf: TMotGraf); override;
//  destructor Destroy; override;
end;

implementation

{ TMiObjeto }
constructor TMiObjeto.Create(mGraf: TMotGraf);
begin
  inherited;
  ReConstGeom;     //Se debe llamar después de crear los puntos de control para poder ubicarlos
  nombre := 'Objeto';
end;
procedure TMiObjeto.ReubicElemen;
//Reubica elementos, del objeto. Es llamado cuando se cambia la posición del objeto, con
//o sin cambio de las dimensiones.
var
  x2: Single;
begin
  inherited;
  x2 := x + width;
end;
procedure TMiObjeto.Dibujar();
begin
  //Dibuja etiqueta
//  v2d.SetPen(clGray, 1);
  v2d.SetText(clWhite, 11,'', false);
  v2d.Texto(x + 2, Y + Height + 20, 0, nombre);
  //muestra un rectángulo
  v2d.SetPen(clWhite, 1, psSolid);
  v2d.FijaRelleno(clBlack);
  v2d.rectangXYr(x, y+10, x+width, y+height,0);
  inherited;
end;

{ TObjGrafDXF }
procedure TObjGrafDXF.PtoCtrl0_Move(xvTar, yvTar, dx, dy: Single);
begin
  P0.x:=xvTar;
  P0.y:=yvTar;
  ReConstGeom;
end;
procedure TObjGrafDXF.PtoCtrl1_Move(xvTar, yvTar, dx, dy: Single);
begin
  P1.x:=xvTar;
  P1.y:=yvTar;
  ReConstGeom;
end;
procedure TObjGrafDXF.PtoCtrlM_Move(xvTar, yvTar, dxv, dyv: Single);
begin
  ReConstGeom;
end;
procedure TObjGrafDXF.SetP0(const xv, yv, zv: Single);
begin
  P0.x:=xv;
  P0.y:=yv;
  P0.z:=zv;
  ReubicElemen;
end;
procedure TObjGrafDXF.SetP1(const xv, yv, zv: Single);
begin
  P1.x:=xv;
  P1.y:=yv;
  P1.z:=zv;
  ReubicElemen;
end;
constructor TObjGrafDXF.Create(mGraf: TMotGraf);
begin
  inherited Create(mGraf);
  //Notar que los puntos de control son estáticos, aunque tal vez sea mejor, crearlos
  //solo cuando el objeto está seleccionado.
  pc0:=AddPtoControl(TD_SUP_IZQ,@PtoCtrl0_Move);
  pc1:=AddPtoControl(TD_SUP_IZQ,@PtoCtrl1_Move);
  pcM:=AddPtoControl(TD_SUP_IZQ,@PtoCtrlM_Move);
  ReConstGeom;     //Se debe llamar después de crear los puntos de control para poder ubicarlos
  nombre := 'Objeto';
end;
procedure TObjGrafDXF.ReubicElemen;
begin
  //Ubica puntos de control
  pc0.Locate(P0);
  pc1.Locate(P1);
  pcM.Locate((P0.x + P1.x)/2, (P0.y + P1.y)/2, (P0.z + P1.z)/2 );
end;
procedure TObjGrafDXF.Dibujar;
var
  pdc  : TPtoCtrl;
  Ptos : Array of TPoint;
  i: Integer;
begin
  If Marcado and Highlight Then begin
    v2d.SetPen(TColor($FF8000), 2, psSolid);
  end else begin
    v2d.SetPen(clWhite, 1);
  end;
  case etype of
  etyLine: begin
      v2d.Line(P0, P1);
    end;
//  etyCircle: begin
//      v2d.Circulo(xv + ent.x0, y + ent.y0,
//                  ent.radius);
//    end;
{  etyPolyline: begin
      //Por eficiencia, se dibuja la polilínea directamente del canvas
      SetLength(Ptos, vertexs.Count);   //dimensiona
      //transforma puntos
      for i:= 0 to vertexs.Count-1 do begin
        Ptos[i].x := v2d.XPant(vertexs[i].x0);
        Ptos[i].y := v2d.YPant(vertexs[i].y0);
      end;
      //v2d.Canvas.Polygon(Ptos);   //dibuja
      v2d.cv.Polyline(Ptos);
    end;}
  end;
  //---------------dibuja marca de seleccion--------------
  if Selected Then begin
    for pdc in PtosControl do pdc.Dibujar;   //Dibuja puntos de control
  end;
end;
function TObjGrafDXF.LoSelecciona(xp, yp: integer): Boolean;
{Versión personalizada}
const
  DSEL = 5;
var
  a, b: Single;
  dx, dy: Int16;
   //tolerancia en pixeles
begin
  {No debería ser necesario actualizar las coordenadas de pantalla de P0 y P1, ya que
  si esta recta se mostró en pantalla, es porque se actualizaron sus coordenadas de
  pantalla:
  v2d.XYpant(P0);
  v2d.XYpant(P1);
  }
  if P0.xp = P1.xp then begin  //Caso recta vertical
     if abs(P0.xp - xp)>DSEL then exit(false);  //excede distancia horizontal
     if P0.yp = P1.yp then begin  //Caso de un punto
       Result := (abs(P0.yp - yp) < DSEL);
     end else begin //Caso de recta vertical común
       if P0.yp > P1.yp then begin  //P0 arriba
          Result := (yp<P0.yp+DSEL) and (yp>P1.yp-DSEL);
       end else begin               //P1 arriba
          Result := (yp<P1.yp+DSEL) and (yp>P0.yp-DSEL);
       end;
     end;
  end else if P0.xp < P1.xp then begin  //P0 a la izquierda
     if xp<P0.xp-DSEL then exit(false);  //escapa de límite
     if xp>P1.xp+DSEL then exit(false);  //escapa de límite
     //Simplifica la comparación, viendo solo una distancia vertical
//     a := (P1.yp - P0.yp)/(P1.xp - P0.xp);  //pendiente
//     b := P0.yp - a*P0.xp;  //Define ecuación de la recta y=ax+b
//     Result := abs(a*xp + b - yp) < DSEL;
     //Forma alternativa, sin divisiones
     dx := P1.xp - P0.xp;   //siempre positivo
     dy := P1.yp - P0.yp;   //positivo o negativo
     if abs(dy)<dx then begin
       Result := abs( (xp - P0.xp)*dy - (yp-P0.yp)*dx ) < DSEL * dx;
     end else begin //abs(dy), es mayor a dx
       Result := abs( (xp - P0.xp)*dy - (yp-P0.yp)*dx ) < DSEL * abs(dy);
     end;
  end else begin                        //P1 a la izquierda
     if xp<P1.xp-DSEL then exit(false);  //escapa de límite
     if xp>P0.xp+DSEL then exit(false);  //escapa de límite
     //Define ecuación de la recta y=ax+b
//     a := (P0.yp - P1.yp)/(P0.xp - P1.xp);  //pendiente
//     b := P1.yp - a*P1.xp;
//     Result := abs(a*xp + b - yp) < DSEL;
      dx := P0.xp - P1.xp;   //siempre positivo
      dy := P0.yp - P1.yp;   //positivo o negativo
      if abs(dy)<dx then begin
        Result := abs( (xp - P1.xp)*dy - (yp-P1.yp)*dx ) < DSEL * dx;
      end else begin //abs(dy), es mayor a dx
        Result := abs( (xp - P1.xp)*dy - (yp-P1.yp)*dx ) < DSEL * abs(dy);
      end;
  end;
end;

end.

