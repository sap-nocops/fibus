import QtQuick 2.9
import QtQuick.Layouts 1.1
import Ubuntu.Components 1.3
import QtQuick.Controls.Suru 2.2
import QtQuick.LocalStorage 2.0

MainView {
    id: root
    objectName: 'mainView'
    applicationName: 'fibus.sap'
    automaticOrientation: true
    property var stops
    property var stopNames
    property var tmpIndexes
    default property var db
    property var errors: {
    	"STOP": 0,
    	"BUS": 1
    }

    function getDatabase() {
        return LocalStorage.openDatabaseSync("fibus_db", "1.0", "StorageDatabase", 1000000);
    }

    function initDb() {
    	root.db = getDatabase()
    	root.db.transaction(
            function(tx) {
                tx.executeSql('CREATE TABLE IF NOT EXISTS favourites(id INTEGER PRIMARY KEY AUTOINCREMENT, fid TEXT, name TEXT, x REAL, y REAL)');
            }
        );
    }

    function isFavourite(id) {
    	var rs;
    	root.db.transaction(
            function(tx) {
    			rs = tx.executeSql('SELECT * FROM favourites WHERE fid = "' + id + '"');
    		}
        );
        return rs.rows.length > 0;
    }

    function toggleFavourite(fav) {
	    root.db.transaction(
	        function(tx) {
		    	var rs = tx.executeSql('SELECT * FROM favourites where fid = "' + fav.id + '"');
		        if (rs.rows.length == 0) {
					tx.executeSql('INSERT INTO favourites (fid, name, x, y)'
					+ ' VALUES ('
					+	'"' + fav.id + '", "' + fav.n + '", ' + fav.x + ', ' + fav.y + ')');
					setIsFavoriteIconVisibility(true);
				} else {
					tx.executeSql('DELETE FROM favourites WHERE fid = "' + fav.id +'"');
					setIsFavoriteIconVisibility(false);
				}
				loadFavourites();
			}
		);
    }

    function setIsFavoriteIconVisibility(isFavourite) {
    	favouriteIconOff.visible = !isFavourite;
    	favouriteIconOn.visible = isFavourite;
    }

    function loadFavourites() {
    	favourite.clear();
		root.db.transaction(
	        function(tx) {
		    	var rs = tx.executeSql('SELECT * FROM favourites');
		        for (var i = 0; i < rs.rows.length; i++) {
		        	var item = rs.rows.item(i);
                    favourite.append(item);
                }
			}
		);
    }

    function initStops() {
        var http = new XMLHttpRequest();
        var url = "http://www.temporealeataf.it/Mixer/Rest/PublicTransportService.svc/stops?urLat=44&urLon=12&llLat=43&llLon=10&getId=true";
        stopNames = [];
        var justOne = false;
        http.onreadystatechange = function() {
            if (http.readyState == 4) {
                if (http.status == 200) {
                    stops = JSON.parse(http.responseText);
                    for(var i in stops) {
                        stopNames.push(stops[i].n);
                    }
                    showFavoriteOrStopContainer();
                    return;
                } else {
                	busError(http);
                }
            }
        };
        if (justOne) {
        	busError();
        }
        http.open("GET", url, true);
        http.send();
    }

    function busError(http) {
        showErrorContainer("Errore nel recupero delle fermate", root.errors.STOP);
    }

    function showBussesByIndex(selectedStopIndex) {
        var selectedStop = stops[tmpIndexes[selectedStopIndex]];
        doShowBusses(selectedStop);
    }

    function showBussesById(selectedStopId) {
    	var selectedStop;
    	for (var s in stops) {
    		if (stops[s].id == selectedStopId) {
				selectedStop = stops[s];
				break;
    		}
    	}
        doShowBusses(selectedStop);
    }

    function showErrorContainer(errorMessage, errorType) {
    	errorText.text = errorMessage;
		errorContainer.errorType = errorType;
    	errorContainer.visible = true;
    	busContainer.visible = false;
	    stopContainer.visible = false;
	    favouriteContainer.visible = false;
    }

    function showBusContainer() {
    	stopContainer.visible = false;
        favouriteContainer.visible = false;
        busContainer.visible = true;
        errorContainer.visible = false;
    }

    function showFavoriteOrStopContainer() {
    	if (favourite.count > 0) {
    		stopContainer.visible = false;
        	favouriteContainer.visible = true;
    	} else {
    		stopContainer.visible = true;
        	favouriteContainer.visible = false;
    	}
        busContainer.visible = false;
        errorContainer.visible = false;
    }

    function doShowBusses(selectedStop) {
    	busContainer.currentStop = selectedStop;
    	var isFav = isFavourite(selectedStop.id);
    	favouriteIconOff.visible = !isFav;
    	favouriteIconOn.visible = isFav;
        var http = new XMLHttpRequest();
        var url = "http://www.temporealeataf.it/Mixer/Rest/PublicTransportService.svc/single?Lat=" + selectedStop.y + "&Lon=" + selectedStop.x + "&nodeId=" + selectedStop.id + "&getSchedule=true";
        http.onreadystatechange = function() {
            if (http.readyState == 4) {
                if (http.status == 200) {
                    showBusContainer();
                    populateBusList(JSON.parse(http.responseText).s);
                    fillSearchText(selectedStop.n);
                    return;
                } else {
                	console.log("error: " + http.status);
            		console.log(http.statusText);
            		errorContainer.stopInError = selectedStop;
            		showErrorContainer("Errore nel recupero dei bus", root.errors.BUS);
                }
            }
        }
        http.open("GET", url, true);
        http.send();
    }

    function fillSearchText(name) {
    	input.text = name;
    }

    function populateBusList(busses) {
    	bus.clear();
        if (busses.length == 0) {
            bus.append({d: -1, n: "", t: ""});
            return;
        }
        for( var i in busses) {
            bus.append(busses[i]);
        }
    }

    function populateStopList(search) {
        tmpIndexes = [];
        stop.clear();
        if (search.length == 0) {
        	busContainer.visible = false;
        	stopContainer.visible = false;
        	favouriteContainer.visible = true;
            return;
        }
        busContainer.visible = false;
        stopContainer.visible = true;
        favouriteContainer.visible = false;
        if (search.length < 2) {
            return;
        }
        stopNames.filter(function(name, index) {
            var match = name.toLowerCase().indexOf(search.toLowerCase()) > -1;
            if (match) {
                tmpIndexes.push(index);
            }
            return match;
        });
        for (var i in tmpIndexes) {
            stop.append(stops[tmpIndexes[i]]);
        }
        if (tmpIndexes.length == 0) {
            stop.append({n: i18n.tr('Nessuna Fermata Trovata')});
        }
    }

    Page {
        anchors.fill: parent

        header: PageHeader {
            id: header
            title: 'Fibus'
            StyleHints {
                foregroundColor: UbuntuColors.red
                backgroundColor: UbuntuColors.purple
                dividerColor: UbuntuColors.red
            }
        }
        
        Column {
        	anchors.top: header.bottom
            width: parent.width
            height: parent.height - header.height

            Rectangle {
            	id: inputContainer
            	height: units.gu(6)
	            width: parent.width
	            color: "white"
	            
	            Row {
	                height: units.gu(6)
	                width: parent.width

		            Rectangle {
		                height: units.gu(6)
		                width: parent.width - units.gu(5)
		                border.width: 1
		                border.color: UbuntuColors.purple
		                radius: 100
		                focus: true

		                TextInput {
		                    id: input
		                    color: "black"
		                    font.pixelSize: units.gu(5)
		                    width: parent.width
		                    height: parent.height

		                    onTextEdited: populateStopList(text)
		                }
		            }

		            Rectangle {
		            	width: units.gu(5)
		            	height: units.gu(5)
			            
			            Icon {
		            		id: emptySearchText
			                width: units.gu(5)
		            		height: units.gu(5)
			                name: "delete"
			                color: "black"
		            	}
		            	
		            	MouseArea {
		                    width: units.gu(5)
		            		height: units.gu(5)
		                    onClicked: {
		                        input.text = "";
		                        populateStopList("");
		                    }
		                }
		            }
		        }
		    }    

            /*
             * STOPS
             */
            Rectangle {
            	id: stopContainer
                width: parent.width
                height: parent.height - input.height
                visible: false
                
                ListView {
                    id: stopList
                    width: parent.width
                    height: parent.height
                    spacing: 1
                    model: ListModel {
                        id: stop;
                    }
                    delegate: Component {
                        Item {
                            height: units.gu(5)
                            width: stopContainer.width
                            Text {
                                text: n
                                font.family: "UbuntuMono"
                                font.pixelSize: units.gu(3)
                            }

                            MouseArea {
                                id: stopClick
                                height: units.gu(5)
                            	width: stopContainer.width
                                onClicked: {
                                    showBussesByIndex(model.index);
                                }
                            }
                        }
                    }
                }
            }

            /*
             * BUS
             */
            Rectangle {
            	id: busContainer
            	visible: false
            	width: parent.width
	            height: parent.height - input.height
	            property var currentStop
            	
            	Column {
	                width: parent.width
	                height: parent.height - input.height

	                Row {
	                	id: iconContainer
	            		width: units.gu(10)
	            		height: units.gu(5)
	            		Rectangle {
	            			width: units.gu(5)
		                	height: units.gu(5)
	            			Icon {
		                		id: favouriteIconOn
				                width: parent.width
		                		height: parent.height
				                name: "starred"
				                color: UbuntuColors.orange
		            		}
		            		Icon {
		                		id: favouriteIconOff
				                width: parent.width
		                		height: parent.height
				                name: "non-starred"
				                color: UbuntuColors.orange
		            		}
		            		MouseArea {
		                        id: toggleFavouriteClick
		                        width: parent.width
		                		height: parent.height
		                        onClicked: {
		                            toggleFavourite(busContainer.currentStop);
		                        }
		                    }
	            		}
		                Rectangle {
	            			width: units.gu(5)
		                	height: units.gu(5)
		            		Icon {
		                		id: refreshBusIcon
				                width: parent.width
		                		height: parent.height
				                name: "reload"
				                color: "black"
		            		}
		            		MouseArea {
		                        id: refreshBusClick
		                        width: parent.width
		                		height: parent.height
		                        onClicked: {
		                            doShowBusses(busContainer.currentStop);
		                    	}
	                    	}
	                    }
	            	}

	                ListView {
	                    id: busList
	                    width: parent.width
	                    height: parent.height - iconContainer.height
	                    spacing: 1
	                    model: ListModel {
	                        id: bus;
	                    }
	                    delegate: Component {
	                        Item {
	                            width: busContainer.width
	                            height: units.gu(5)                     

	                            Row {
	                    			height: parent.height
	                                width: parent.width
	                            	Text {
										height: parent.height
	                                	width: parent.width

	                                    function formatBus(d, number, finalStop) {
	                                        var delay = parseInt(d);
	                                        if (delay > -1) {
                                                var localizedHour = parseInt(new Date().toLocaleTimeString(Qt.locale("it_IT"), "hh"));
                                                delay = delay / 1000;
                                                var hours = parseInt(delay / 3600);
                                                var hourShift = localizedHour - hours;
                                                if (hourShift > 0 ) {
                                                    hours += hourShift;
                                                } else {
                                                    hours += 1;
                                                }
                                                var min = parseInt((delay % 3600) / 60);
	                                            min = (min > 9) ? min : '0' + min;
	                                            hours = (hours > 9) ? hours : '0' + hours;
	                                            return hours + ':' + min + ' ' + number + ' ' + finalStop;
	                                        }
	                                        return i18n.tr('Nessun Bus Trovato');
	                                    }

	                                    text: formatBus(d, n, t)
	                                    font.family: "UbuntuMono"
	                                    font.pixelSize: units.gu(3)
	                                }
	                            }
	                        }
	                    }
	                }
	            }
            }
            

            /*
             * Preferiti
             */
            Rectangle {
            	id: favouriteContainer
                width: parent.width
                height: parent.height - input.height
                visible: true

                ListView {
                    id: favouritesList
                    width: favouriteContainer.width
                    height: parent.height
                    spacing: 1
                    model: ListModel {
                        id: favourite;
                    }
                    delegate: Component {
                        Item {
                            width: favouriteContainer.width
                            height: units.gu(5)
								
                            Text {
                                text: name
                                font.family: "UbuntuMono"
                                font.pixelSize: units.gu(3)
                            }

                            MouseArea {
                                id: favouriteClick
                                height: units.gu(5)
                                width: favouriteContainer.width
                                onClicked: {
                                    showBussesById(model.fid);
                                }
                            }
                        }
                    }
                }
            }

            /*
             * Errore
             */
            Rectangle {
            	id: errorContainer
                width: parent.width
                height: parent.height - input.height
                visible: false
                default property var errorType

                Text {
                	id: errorText
                    text: ""
                    font.family: "UbuntuMono"
                    font.pixelSize: units.gu(3)
                    color: UbuntuColors.red
                }

                Rectangle {
        			width: units.gu(5)
                	height: units.gu(5)
                	anchors.horizontalCenter: parent.center
                	anchors.verticalCenter: parent.center

            		Icon {
                		id: refreshStopsIcon
		                width: parent.width
                		height: parent.height
		                name: "reload"
		                color: "black"
            		}
            		MouseArea {
                        id: refreshStopsClick
                        width: parent.width
                		height: parent.height
                        onClicked: {
                        	switch(errorContainer.errorType) {
	   							case root.errors.STOP:
	   								initStops();
	   								break;
	   							case root.errors.BUS:
	   								console.log("BUSSSSssssssSSSSSS " + JSON.stringify(errorContainer.stopInError));
	   								doShowBusses(errorContainer.stopInError);
	   								break;
	   						}
                    	}
                	}
                }
            }
        }
    }



    Component.onCompleted : {
    	initDb();
    	loadFavourites();
        initStops();
        input.forceActiveFocus();
    }
}
